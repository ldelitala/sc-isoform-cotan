#!/usr/bin/env Rscript

# Step 01 — clean simpleaf barcodes, keep spliced transcripts, round the counts
# and store the Seurat object the COTAN initialisation reads.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

cfg <- load_config()
p <- resolve_paths(cfg)
require_paths(p, "input_seurat")
target <- out_file(p, object_path(p, "ready_seurat"))

check_io(
  p,
  reads = c("raw seurat object" = p$input_seurat),
  writes = c("ready-to-coex seurat" = target)
)
step_log(p, log_name(p, "prepare_seurat"))

log_info(sprintf("Loading Seurat object: %s", p$input_seurat))
seurat_obj <- readRDS(p$input_seurat)

seurat_obj <- clean_simpleaf_barcodes(seurat_obj)

spliced_prefix <- step_cfg(p, "prepare_seurat", "spliced_prefix")
if (is.null(spliced_prefix)) {
  log_info("Filtering spliced transcripts (library default prefix)")
  seurat_obj <- filter_spliced_transcripts(seurat_obj)
} else {
  log_info(sprintf("Filtering spliced transcripts with prefix '%s'", spliced_prefix))
  seurat_obj <- filter_spliced_transcripts(seurat_obj, prefix = spliced_prefix)
}

seurat_obj <- round_seurat_counts(
  seurat_obj,
  output_dir = dirname(target),
  file_name = basename(target)
)
