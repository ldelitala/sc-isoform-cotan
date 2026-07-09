#!/usr/bin/env Rscript

box::use(
  data/lorenzo_delitala/src/pipeline/bin/r_modules/cotan_config[config_cotan_workflow],
  data/lorenzo_delitala/src/pipeline/bin/r_modules/qc_seurat[
    filter_spliced_transcripts,
    create_test_subset,
    filter_mt_transcripts,
    filter_iterative_sparsity
  ],
  data/lorenzo_delitala/src/pipeline/bin/r_modules/logger
)

# TEMPORARY HARDCODING OF PATHS
combined_raw_matrix_path <-
  "/data/lorenzo_delitala/runs/arrigoni2023/results/combined_raw_matrix.seurat.rds"

mt_transcript_list_path <-
  "/data/lorenzo_delitala/runs/arrigoni2023/results/transcript_index/modified_index/index/mt_transcripts.txt"

mt_transcripts_list <- readLines(mt_transcript_list_path)

mt_transcripts_list <- trimws(mt_transcripts_list)

seurat_obj <- readRDS(combined_raw_matrix_path)


config_cotan_workflow(logging_level = 3L)

seurat_obj <- filter_spliced_transcripts(seurat_obj)

seurat_obj <- create_test_subset(seurat_obj, num_features = 10000, num_cells = 8000, seed = 42)

filtered_seurat_obj <- filter_mt_transcripts(seurat_obj, mt_transcripts_list)

seurat_obj <- filter_iterative_sparsity(seurat_obj, cells_cutoff = 0.003, genes_cutoff = 0.002)
