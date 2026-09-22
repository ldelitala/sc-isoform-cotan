#!/usr/bin/env Rscript

# Step 08 — compare two DTU candidate tables (transcript-level vs gene-cluster
# level) and write the shared / exclusive tables.
#
# Ported from ding_cortex_2/Rscripts/confront_dtu.R. The output format is the
# released one: dplyr-join semantics are kept (they append the `_file2` columns
# after the `_file1` ones, which `merge()` would not), while the column maths use
# base R.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

#' Order-independent identity of a DTU event: gene id plus the two transcripts
create_dtu_id <- function(df) {
  transcript_min <- pmin(df$Transcript_A, df$Transcript_B)
  transcript_max <- pmax(df$Transcript_A, df$Transcript_B)
  df$Tr_min <- transcript_min
  df$Tr_max <- transcript_max
  df$DTU_ID <- paste(df$Gene_ID, transcript_min, transcript_max, sep = "___")
  df
}

cfg <- load_config()
p <- resolve_paths(cfg)

compare_cfg <- step_cfg(p, "compare_dtu")
if (is.null(compare_cfg) || length(compare_cfg$files) != 2L) {
  die("this config needs 'steps: compare_dtu: files' with exactly two entries")
}
required_outputs <- c("shared", "exclusive1", "exclusive2")
if (!all(required_outputs %in% names(compare_cfg$outputs))) {
  die("compare_dtu: outputs must define ", paste(required_outputs, collapse = ", "))
}
require_paths(p, "workdir")

inputs <- vapply(compare_cfg$files, function(file_name) {
  in_file(p, cfg_path(p, "workdir", file_name))
}, character(1L))
targets <- vapply(compare_cfg$outputs, function(file_name) {
  out_path(p, "workdir", file_name)
}, character(1L))

check_io(
  p,
  reads = stats::setNames(inputs, compare_cfg$files),
  writes = targets
)
step_log(p, log_name(p, "compare_dtu"))

log_header("Compare DTU candidates")

log_info(sprintf("Loading %s", basename(inputs[[1]])))
dtu_1 <- readr::read_csv(inputs[[1]], show_col_types = FALSE)
log_info(sprintf("Loading %s", basename(inputs[[2]])))
dtu_2 <- readr::read_csv(inputs[[2]], show_col_types = FALSE)

dtu_1_id <- create_dtu_id(dtu_1)
dtu_2_id <- create_dtu_id(dtu_2)

log_info("Identifying shared and exclusive DTU events...")
join_cols <- "DTU_ID"
if ("Gene_ID" %in% colnames(dtu_1_id)) {
  join_cols <- c(join_cols, "Gene_ID")
}
if ("Gene_Name" %in% colnames(dtu_1_id)) {
  join_cols <- c(join_cols, "Gene_Name")
}

shared_dtus <- dplyr::inner_join(dtu_1_id, dtu_2_id, by = join_cols, suffix = c("_file1", "_file2"))
exclusive_file1 <- dplyr::anti_join(dtu_1_id, dtu_2_id, by = "DTU_ID")
exclusive_file2 <- dplyr::anti_join(dtu_2_id, dtu_1_id, by = "DTU_ID")

log_stat(sprintf("Total candidates in File 1: %d", nrow(dtu_1)))
log_stat(sprintf("Total candidates in File 2: %d", nrow(dtu_2)))
log_stat(sprintf("SHARED DTU events: %d", nrow(shared_dtus)))
log_stat(sprintf("EXCLUSIVE DTU events in File 1: %d", nrow(exclusive_file1)))
log_stat(sprintf("EXCLUSIVE DTU events in File 2: %d", nrow(exclusive_file2)))

if (nrow(shared_dtus) > 0) {
  log_info("Calculating COEX differences for shared events...")
  shared_dtus$COEX_Diff <- abs(shared_dtus$COEX_Score_file1 - shared_dtus$COEX_Score_file2)
  shared_dtus <- shared_dtus[order(-shared_dtus$COEX_Diff), ]

  log_stat(sprintf("Mean COEX_Score difference for shared events: %.4f",
                   mean(shared_dtus$COEX_Diff, na.rm = TRUE)))
}

log_info(sprintf("Writing results to: %s", dirname(targets[[1]])))
readr::write_csv(shared_dtus, targets[["shared"]])
readr::write_csv(exclusive_file1, targets[["exclusive1"]])
readr::write_csv(exclusive_file2, targets[["exclusive2"]])
