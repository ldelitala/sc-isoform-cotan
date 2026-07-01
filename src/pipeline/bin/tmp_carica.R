#!/usr/bin/env Rscript

# TEMPORARY HARDCODING OF PATHS
combined_raw_matrix_path <-
  "/data/lorenzo_delitala/runs/arrigoni2023/results/combined_raw_matrix.seurat.rds" # nolint: line_length_linter.

mt_transcript_list_path <-
  "/data/lorenzo_delitala/runs/arrigoni2023/results/transcript_index/modified_index/index/mt_transcripts.txt" # nolint: line_length_linter.

mt_transcripts_list <- readLines(mt_transcript_list_path)

mt_transcripts_list <- trimws(mt_transcripts_list)

seurat_obj <- readRDS(combined_raw_matrix_path)
