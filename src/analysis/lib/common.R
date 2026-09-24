#!/usr/bin/env Rscript

# Shared plumbing (lib/common.R) for every step under analysis/R/.
#
# A step does exactly four things with this file:
#   1. sources it (see the four bootstrap lines at the top of each R/0*.R script)
#   2. cfg <- load_config()          parses --config/--root/--out-dir/--dry-run
#   3. p   <- resolve_paths(cfg)     turns the config into absolute paths
#   4. check_io(p, reads, writes)    validates inputs, or prints the plan and exits
#                                    when --dry-run was given
#
# Nothing here knows about a specific dataset: all dataset knowledge lives in
# analysis/config/*.yaml, and all library knowledge lives in the cotanisoform package.

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(cotanisoform)
})

# base R >= 4.4 provides this; the definition keeps older interpreters working
`%||%` <- function(x, y) if (is.null(x)) y else x

die <- function(...) {
  message("ERROR: ", ...)
  quit(save = "no", status = 1L)
}

step_options <- function() {
  list(
    make_option(
      c("-c", "--config"),
      type = "character", default = NULL, metavar = "FILE",
      help = "Dataset YAML config describing paths and parameters (required)"
    ),
    make_option(
      "--root",
      type = "character", default = NULL, metavar = "DIR",
      help = "Override the config 'root:' key (env COTANISO_ROOT also works)"
    ),
    make_option(
      "--out-dir",
      dest = "out_dir", type = "character", default = NULL, metavar = "DIR",
      help = "Write this step's outputs (and log) here instead of the configured directories"
    ),
    make_option(
      "--dry-run",
      dest = "dry_run", action = "store_true", default = FALSE,
      help = "Resolve and report every path, then exit without computing anything"
    )
  )
}

#' Parse CLI options and load the dataset config
#'
#' @param option_list Extra optparse options a step may add.
#' @param argv Argument vector, defaults to the command line.
#' @return The config as a list, with `root`, `out_dir` and `dry_run` resolved.
load_config <- function(option_list = list(), argv = commandArgs(trailingOnly = TRUE)) {
  parser <- OptionParser(option_list = c(step_options(), option_list))

  if (length(argv) > 0L && any(argv %in% c("-h", "--help"))) {
    print_help(parser)
    quit(save = "no", status = 0L)
  }

  opt <- parse_args(parser, args = argv)

  if (is.null(opt$config)) {
    print_help(parser)
    die("--config FILE is required")
  }
  if (!file.exists(opt$config)) {
    die("config file not found: ", opt$config)
  }

  cfg <- yaml::read_yaml(opt$config)

  root <- opt$root
  if (is.null(root) || !nzchar(root)) {
    root <- Sys.getenv("COTANISO_ROOT", unset = "")
  }
  if (!nzchar(root)) {
    root <- cfg$root %||% ""
  }
  if (!nzchar(root)) {
    die("no data root: set 'root:' in the config, pass --root DIR, or set COTANISO_ROOT")
  }
  if (!dir.exists(root)) {
    die("data root does not exist: ", root)
  }

  cfg$root <- root
  cfg$out_dir <- opt$out_dir
  cfg$dry_run <- isTRUE(opt$dry_run)
  cfg$cli <- opt
  cfg
}

#' Turn the relative paths of a config into absolute ones
#'
#' Paths are understood relative to `root`; absolute paths are taken as they are.
#' Outputs keep resolving through [out_dir()], so `--out-dir` can redirect them.
resolve_paths <- function(cfg) {
  absolute <- function(x) {
    if (is.null(x) || !nzchar(x)) {
      return(NULL)
    }
    if (substr(x, 1L, 1L) == "/") x else file.path(cfg$root, x)
  }

  paths <- cfg$paths %||% list()
  p <- list(root = cfg$root, cfg = cfg, dry_run = isTRUE(cfg$dry_run))

  for (key in c(
    "workdir", "logs", "objects", "plots", "t2g", "gene_id_to_name", "t2gene_name",
    "input_seurat", "input_matrix", "input_matrix_genes", "input_matrix_cells",
    "mt_transcripts", "part_qc_tsv", "valid_cells_tsv"
  )) {
    p[[key]] <- absolute(paths[[key]])
  }

  p$cell_type_files <- if (length(paths$cell_type_files) > 0L) {
    vapply(paths$cell_type_files, absolute, character(1L), USE.NAMES = TRUE)
  } else {
    NULL
  }

  p$obj <- lapply(cfg$objects %||% list(), function(file_name) {
    file.path(p$objects, file_name)
  })

  p
}

#' Look up a step block (or one of its keys) in the config
step_cfg <- function(p, step, key = NULL, default = NULL) {
  step_block <- (p$cfg$steps %||% list())[[step]]
  if (is.null(step_block)) {
    return(default)
  }
  if (is.null(key)) {
    return(step_block)
  }
  step_block[[key]] %||% default
}

#' Look up an object file name by its key in `objects:`
object_path <- function(p, key) {
  path <- p$obj[[key]]
  if (is.null(path)) {
    die("config has no 'objects:", key, "' entry (needed by this step)")
  }
  path
}

#' Fail early and clearly when a config cannot serve this step
#'
#' Steps are shared by configurations that do not all define the same inputs
#' (a gene-level run has no Seurat object, a transcript-level run has no count
#' matrix). Without this check such a mismatch surfaces as an obscure error from
#' `basename(NULL)` or from a missing file deep inside the library.
require_paths <- function(p, ...) {
  keys <- c(...)
  absent <- keys[vapply(keys, function(key) is.null(p[[key]]), logical(1L))]
  if (length(absent) > 0L) {
    die(
      "this config has no ", paste0("'paths: ", absent, "'", collapse = ", "),
      " entry (level '", p$cfg$level %||% "?", "'); it is not meant to run this step"
    )
  }
  invisible(TRUE)
}

#' Directory a step writes to: `--out-dir` when given, else the named config path
out_dir <- function(p, kind = "objects") {
  dir <- p$cfg$out_dir %||% p[[kind]]
  if (is.null(dir)) {
    die("no output directory: set 'paths:", kind, "' in the config or pass --out-dir")
  }
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  dir
}

#' Full path of an output file inside an output directory
out_path <- function(p, kind, file_name) {
  file.path(out_dir(p, kind), file_name)
}

#' Path of a file inside a config directory, ignoring `--out-dir`
#'
#' [out_path()] is for outputs and honours `--out-dir`; inputs must be looked up in
#' the config instead (with [in_file()] then preferring an existing `--out-dir`
#' shadow), otherwise a step would try to read what a previous run wrote to a
#' scratch directory.
cfg_path <- function(p, kind, file_name) {
  dir <- p[[kind]]
  if (is.null(dir)) {
    die("config has no 'paths:", kind, "' entry")
  }
  file.path(dir, file_name)
}

#' Redirect a config-declared output file through `--out-dir` when it was given
#'
#' Some outputs are declared as whole paths in the config (`t2gene_name`, the
#' per-step object files). This keeps them where the config says, unless
#' `--out-dir` asks for a scratch location, in which case only the file name is
#' reused.
out_file <- function(p, path) {
  dir <- p$cfg$out_dir
  if (is.null(dir)) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    path
  } else {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    file.path(dir, basename(path))
  }
}

#' Read-side counterpart of [out_file()]
#'
#' `--out-dir` shadows the inputs too: when a file with the same name exists in
#' the scratch directory it is preferred, so that `run_all.R --out-dir DIR` reads
#' back what it wrote instead of the older objects of the config. Without
#' `--out-dir` the config path is returned unchanged.
in_file <- function(p, path) {
  dir <- p$cfg$out_dir
  if (is.null(dir)) {
    return(path)
  }
  shadow <- file.path(dir, basename(path))
  if (file.exists(shadow)) {
    log_info(sprintf("Reading the --out-dir copy: %s", shadow))
    return(shadow)
  }
  path
}

#' Log file name of a step: `<step>.<level>.log`, as in the released drivers
log_name <- function(p, step) {
  paste0(step, ".", p$cfg$level %||% "run", ".log")
}

#' Combine per-cell-line barcode files into the single QC list a run uses
#'
#' Used by runs whose valid cells are described by one file per cell line
#' (arrigoni): the union of the barcodes is written as a headerless TSV, which
#' `flag_valid_cells_from_tsv()` then reads.
combine_barcode_files <- function(file_list, output_path) {
  all_barcodes <- character()

  for (cell_line in names(file_list)) {
    file_path <- file_list[[cell_line]]
    if (!file.exists(file_path)) {
      log_warn(sprintf("File does not exist and will be skipped: %s", file_path))
      next
    }
    barcodes <- utils::read.table(file_path, header = FALSE, stringsAsFactors = FALSE)
    log_stat(sprintf("%s: %d barcodes", cell_line, nrow(barcodes)))
    all_barcodes <- c(all_barcodes, barcodes[[1]])
  }

  all_barcodes <- unique(all_barcodes)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(
    all_barcodes,
    file = output_path,
    sep = "\t",
    quote = FALSE,
    row.names = FALSE,
    col.names = FALSE
  )

  log_stat(sprintf("Combined QC barcodes: %d unique", length(all_barcodes)))
  invisible(all_barcodes)
}

#' Start the COTAN log for this step
#'
#' Log file names and levels stay as they were in the released drivers
#' (`cotan_calc.log`, `init_cotan.transcript.log`, ...); `config_workflow()`
#' appends `_N` when a file with the same name already exists.
step_log <- function(p, file_name) {
  log_dir <- p$cfg$out_dir %||% p$logs
  if (is.null(log_dir)) {
    stop("config has no 'paths: logs' entry and no --out-dir was given")
  }
  config_workflow(
    logging_level = p$cfg$logging_level %||% 3L,
    output_dir = log_dir,
    file_name = file_name
  )
}

#' Validate inputs; under `--dry-run` report the plan and exit successfully
#'
#' @param p Result of [resolve_paths()].
#' @param reads Named character vector: what is read -> where it should be.
#' @param writes Named character vector: what is written -> where it goes.
check_io <- function(p, reads = character(), writes = character()) {
  reads <- reads[!vapply(reads, is.null, logical(1L))]
  present <- file.exists(reads)

  if (isTRUE(p$dry_run)) {
    cat("== DRY RUN:", p$cfg$dataset, "/", p$cfg$level %||% "?", "==\n")
    for (i in seq_along(reads)) {
      cat(sprintf("  %-7s %s\n", if (present[[i]]) "read" else "MISSING", reads[[i]]))
    }
    for (name in names(writes)) {
      cat(sprintf("  %-7s %s\n", "write", writes[[name]]))
    }
    quit(save = "no", status = 0L)
  }

  if (any(!present)) {
    for (i in which(!present)) {
      message("MISSING: ", names(reads)[[i]], " -> ", reads[[i]])
    }
    die(sum(!present), " input(s) missing; run the earlier step first")
  }

  invisible(TRUE)
}
