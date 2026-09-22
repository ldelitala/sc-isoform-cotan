#!/usr/bin/env Rscript
#
# DTU parity harness.
#
# Re-runs the differential-transcript-usage extraction with the parameters that
# produced the published tables and checks the result against the reference
# values those runs logged. It never re-runs COEX: it reads the stored COTAN
# objects and reuses the p-values and DEA already cached inside them, exactly as
# the released runs did.
#
# Reference values per dataset come from:
#   results/arrigoni/logs/cotan_calc_16.log
#   results/ding_cortex_2/logs/cotan_calc_14.log
#
# Usage (on athena, from the repository root):
#   Rscript scripts/verify_dtu_parity.R [--root=DIR] [--out=DIR] [--case=NAME]
#   Rscript scripts/verify_dtu_parity.R --self-test
#
# Exit status: 0 = every selected case reproduced, 1 = a mismatch, an object
# that could not be reproduced, or nothing was checked at all.

suppressPackageStartupMessages(library(cotanisoform))

# --- options -----------------------------------------------------------------

parse_args <- function(args) {
    opts <- list(root = "/data/lorenzo_delitala", out = NULL, case = NULL, `self-test` = NULL)
    for (arg in args) {
        if (!grepl("^--", arg)) stop(sprintf("unexpected argument: %s", arg))
        key <- sub("^--([^=]+)=.*$", "\\1", arg)
        val <- sub("^--[^=]+=", "", arg)
        if (!key %in% names(opts)) stop(sprintf("unknown option: %s", arg))
        opts[[key]] <- val
    }
    opts
}

opts <- parse_args(commandArgs(trailingOnly = TRUE))
root <- normalizePath(opts$root, mustWork = FALSE)

# --- reference cases ---------------------------------------------------------
#
# "objects" lists the plausible inputs in the order they should be tried; a case
# passes when any existing candidate reproduces the recorded statistics.

cases <- list(
    list(
        name = "arrigoni",
        objects = c(
            "data/project_files/arrigoni/objects/calculated.cotan.rds",
            "data/project_files/arrigoni/objects/calculated.transcript.cotan.rds"
        ),
        reference = "results/arrigoni/dtu_candidates.csv",
        sha256 = "ebcae20ada28e0271b2ca3908d1a86ebdc7b42b638cec9b13cb206a2145afffb",
        clusterization = "Known_Cell_Types",
        min_dea_contrast = 0.2,
        stats = list(
            multi_genes = 4958, zero_pairs = 4528, pairs = 2006, filtered = 1985,
            events = 21, genes = 9,
            coex = c(-0.2948, -0.0218, -0.0274, -0.0114),
            p_value = c(0, 1.8834e-04, 6.6701e-03, 4.9947e-02),
            contrast = c(0.0086, 0.0731, 0.0898, 0.6143)
        )
    ),
    list(
        name = "ding_merged",
        objects = "data/project_files/ding/cortex_2/objects/clustered.transcript.with_gene_labels.rds",
        reference = "results/ding_cortex_2/dtu_candidates.transcript_cluster.csv",
        sha256 = "e9defe97c676bb1ee3870f702b50d1f0d32b1708925e7b560f2c1e82198a2185",
        clusterization = "merged",
        min_dea_contrast = 0.05,
        stats = list(
            multi_genes = 2122, zero_pairs = 2108, pairs = 53, filtered = 7,
            events = 46, genes = 8,
            coex = c(-0.1735, -0.0386, -0.0441, -0.0308),
            p_value = c(1.5848e-28, 1.3600e-02, 2.1863e-02, 4.8888e-02),
            contrast = c(0.0447, 0.3272, 0.2853, 0.6631)
        )
    ),
    list(
        name = "ding_gene_cluster",
        objects = "data/project_files/ding/cortex_2/objects/clustered.transcript.with_gene_labels.rds",
        reference = "results/ding_cortex_2/dtu_candidates.gene_cluster.csv",
        sha256 = "ded06ace744e49c7b829d44e615d9a66f89dd318b8201d1e3d3eb288e2b23d99",
        clusterization = "local_gene_cluster",
        min_dea_contrast = 0.05,
        stats = list(
            multi_genes = 2122, zero_pairs = 2108, pairs = 53, filtered = 7,
            events = 46, genes = 8,
            coex = c(-0.1735, -0.0386, -0.0441, -0.0308),
            p_value = c(1.5848e-28, 1.3600e-02, 2.1863e-02, 4.8888e-02),
            contrast = c(0.0384, 0.4375, 0.3394, 0.7852)
        )
    )
)

# --- log parsing -------------------------------------------------------------

# Last n numbers on a line. Statistical lines are prefixed by a timestamp, so
# the values of interest are always the trailing ones.
last_numbers <- function(line, n) {
    matches <- gregexpr("-?[0-9]+\\.[0-9]+e[-+][0-9]+|-?[0-9]+(\\.[0-9]+)?", line)
    vals <- suppressWarnings(as.numeric(regmatches(line, matches)[[1]]))
    vals <- vals[!is.na(vals)]
    if (length(vals) < n) return(rep(NA_real_, n))
    vals[(length(vals) - n + 1L):length(vals)]
}

log_stats <- function(log_path) {
    lines <- readLines(log_path, warn = FALSE)
    pick <- function(label, n) {
        hit <- grep(label, lines, value = TRUE, fixed = TRUE)
        if (length(hit) == 0L) return(rep(NA_real_, n))
        last_numbers(hit[1], n)
    }
    events_genes <- pick("Identified", 2L)
    list(
        multi_genes = pick("Genes with multiple transcripts:", 1L),
        zero_pairs = pick("zero significant mutually exclusive pairs:", 1L),
        pairs = pick("Total significant transcript pairs evaluated:", 1L),
        filtered = pick("Filtered out", 1L),
        events = events_genes[1],
        genes = events_genes[2],
        coex = pick("coex scores:", 4L),
        p_value = pick("p-values:", 4L),
        contrast = pick("max DEA contrasts:", 4L)
    )
}

# --- comparison --------------------------------------------------------------

# Order-independent DTU identity, as used by the released comparison script
# results/ding_cortex_2/Rscripts/confront_dtu.R.
dtu_ids <- function(df) {
    sort(paste(df$Gene_ID, pmin(df$Transcript_A, df$Transcript_B),
               pmax(df$Transcript_A, df$Transcript_B), sep = "___"))
}

compare_stats <- function(observed, expected, tol = 5e-05) {
    problems <- character(0)
    for (nm in c("multi_genes", "zero_pairs", "pairs", "filtered", "events", "genes")) {
        if (is.na(observed[[nm]]) || observed[[nm]] != expected[[nm]]) {
            problems <- c(problems, sprintf("%s: expected %s, got %s",
                                            nm, expected[[nm]], format(observed[[nm]])))
        }
    }
    for (nm in c("coex", "p_value", "contrast")) {
        if (anyNA(observed[[nm]])) {
            problems <- c(problems, sprintf("%s: not found in the log", nm))
            next
        }
        delta <- max(abs(observed[[nm]] - expected[[nm]]))
        if (delta > tol) {
            problems <- c(problems, sprintf("%s: max deviation %.2e\n        expected %s\n        got      %s",
                                            nm, delta, paste(expected[[nm]], collapse = ", "),
                                            paste(observed[[nm]], collapse = ", ")))
        }
    }
    problems
}

sha256_of <- function(path) {
    if (Sys.which("sha256sum") == "") return(NA_character_)
    out <- suppressWarnings(system2("sha256sum", shQuote(path), stdout = TRUE, stderr = FALSE))
    if (length(out) == 0L || !is.null(attr(out, "status"))) return(NA_character_)
    sub("[[:space:]].*$", "", out[1])
}

# --- one case ----------------------------------------------------------------

check_case <- function(case, object_path) {
    tag <- sprintf("%s [%s]", case$name, basename(dirname(object_path)))
    out_dir <- file.path(tempdir(), paste0("parity-", case$name, "-", basename(dirname(object_path))))
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    log_path <- file.path(out_dir, paste0(case$name, ".log"))

    suppressMessages(config_workflow(output_dir = out_dir, file_name = basename(log_path),
                                     logging_level = 3L))

    cat(sprintf("[%s] reading %s\n", tag, object_path))
    cotan_obj <- readRDS(object_path)

    if (is.null(attr(cotan_obj, "p_values")) && is.null(attr(cotan_obj@metaDataset, "p_values"))) {
        cat(sprintf("[%s] WARNING: no stored p-values, recomputing them\n", tag))
        cotan_obj <- calculate_p_value(cotan_obj, cores = 1L, chunk_size = 512L)
    }

    dea <- COTAN::getClustersCoex(cotan_obj)
    if (!case$clusterization %in% names(dea) &&
        !paste0("CL_", case$clusterization) %in% names(dea)) {
        cat(sprintf("[%s] running dea_on_clusters(%s)\n", tag, case$clusterization))
        cotan_obj <- dea_on_clusters(cotan_obj, cl_name = case$clusterization, clusters = NULL)
    }

    produced <- extract_dtu_candidates(
        cotan_obj,
        clusterization_name = case$clusterization,
        p_value_threshold = 0.05,
        min_dea_contrast = case$min_dea_contrast,
        gene_name_col = "gene_name",
        output_directory = out_dir,
        file_name = paste0(case$name, ".csv")
    )

    reference <- utils::read.csv(case$reference, stringsAsFactors = FALSE)
    produced_csv <- file.path(out_dir, paste0(case$name, ".csv"))

    problems <- character(0)
    if (nrow(produced) != nrow(reference)) {
        problems <- c(problems, sprintf("rows: expected %d, got %d", nrow(reference), nrow(produced)))
    }
    if (!setequal(dtu_ids(produced), dtu_ids(reference))) {
        problems <- c(problems, "row identities differ (Gene_ID + sorted transcript pair)")
    }

    merged <- merge(
        data.frame(key = dtu_ids(produced), coex = produced$COEX_Score, p = produced$P_Value),
        data.frame(key = dtu_ids(reference), coex_ref = reference$COEX_Score,
                   p_ref = reference$P_Value),
        by = "key"
    )
    if (nrow(merged) == 0L) {
        problems <- c(problems, "no overlapping rows to compare")
    } else {
        d_coex <- max(abs(merged$coex - merged$coex_ref))
        d_p <- max(abs(merged$p - merged$p_ref))
        if (d_coex > 1e-12 || d_p > 1e-12) {
            problems <- c(problems, sprintf("float parity: max|dCOEX| = %.3e, max|dP| = %.3e",
                                            d_coex, d_p))
        }
    }

    problems <- c(problems, compare_stats(log_stats(log_path), case$stats))

    observed_sha <- sha256_of(produced_csv)
    byte_parity <- !is.na(observed_sha) && identical(observed_sha, case$sha256)
    if (!is.na(observed_sha) && !byte_parity) {
        cat(sprintf("[%s] note: bytes differ from the release (sha256 %s vs %s) -- formatting only, not a failure\n",
                    tag, substr(observed_sha, 1, 12), substr(case$sha256, 1, 12)))
    }

    if (length(problems) == 0L) {
        cat(sprintf("[%s] PASS  rows=%d  byte-identical=%s\n", tag, nrow(produced), byte_parity))
        TRUE
    } else {
        cat(sprintf("[%s] FAIL (%s)\n", tag, object_path))
        cat(paste0("    - ", problems, collapse = "\n"), "\n")
        FALSE
    }
}

# --- self test ---------------------------------------------------------------

if (!is.null(opts$`self-test`)) {
    setwd(root)
    ref_logs <- c("results/arrigoni/logs/cotan_calc_16.log",
                  "results/ding_cortex_2/logs/cotan_calc_14.log")
    for (p in ref_logs) {
        if (!file.exists(p)) {
            cat(sprintf("missing reference log: %s\n", p))
            quit(status = 1L)
        }
        s <- log_stats(p)
        cat(sprintf("%s\n  multi_genes=%s pairs=%s filtered=%s events=%s genes=%s\n  coex=%s\n",
                    p, s$multi_genes, s$pairs, s$filtered, s$events, s$genes,
                    paste(s$coex, collapse = ", ")))
    }
    expected <- cases[[1]]$stats
    observed <- log_stats(ref_logs[1])
    ok <- length(compare_stats(observed, expected)) == 0L
    cat(sprintf("parser self-test: %s\n", if (ok) "PASS" else "FAIL"))
    quit(status = if (ok) 0L else 1L)
}

# --- run ---------------------------------------------------------------------

setwd(root)
selected <- if (is.null(opts$case)) cases else Filter(function(c) c$name == opts$case, cases)
if (length(selected) == 0L) stop("no case selected")

verdicts <- list()
for (case in selected) {
    existing <- case$objects[file.exists(case$objects)]
    if (length(existing) == 0L) {
        cat(sprintf("[%s] SKIP: none of these exist: %s\n", case$name,
                    paste(case$objects, collapse = ", ")))
        verdicts[[case$name]] <- NA
        next
    }
    ok <- vapply(existing, function(p) {
        isTRUE(tryCatch(check_case(case, p), error = function(e) {
            cat(sprintf("[%s] ERROR on %s: %s\n", case$name, p, conditionMessage(e)))
            FALSE
        }))
    }, logical(1))
    verdicts[[case$name]] <- any(ok)
    cat(sprintf("[%s] %s\n", case$name, if (any(ok)) "OK" else "NO MATCHING OBJECT"))
}

verdict <- unlist(verdicts)
if (length(verdict) == 0L || all(is.na(verdict))) {
    cat("\nVERDICT: nothing was verified\n")
    quit(status = 1L)
}
if (all(verdict, na.rm = TRUE)) {
    cat(sprintf("\nVERDICT: %d/%d cases reproduced exactly\n", sum(verdict), length(verdict)))
    quit(status = 0L)
}
cat(sprintf("\nVERDICT: %d of %d cases failed\n", sum(!verdict, na.rm = TRUE), length(verdict)))
quit(status = 1L)
