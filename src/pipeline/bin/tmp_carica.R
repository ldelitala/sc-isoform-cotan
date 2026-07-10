#!/usr/bin/env Rscript

library(cotan.deli)

# TEMPORARY HARDCODING OF PATHS
combined_raw_matrix_path <-
  "/data/lorenzo_delitala/runs/arrigoni2023/results/combined_raw_matrix.seurat.rds"

mt_transcript_list_path <-
  "/data/lorenzo_delitala/runs/arrigoni2023/results/transcript_index/modified_index/index/mt_transcripts.txt"

mt_transcripts_list <- readLines(mt_transcript_list_path)

mt_transcripts_list <- trimws(mt_transcripts_list)

seurat_obj <- readRDS(combined_raw_matrix_path)

config_cotan_workflow(logging_level = 3L, output_dir = "/data/lorenzo_delitala/logs/")


seurat_obj <- filter_spliced_transcripts(seurat_obj)

seurat_obj <- filter_mt_transcripts(seurat_obj, mt_transcripts_list)

seurat_obj <- round_seurat_counts(seurat_obj)

seurat_obj <- filter_empty_droplets(seurat_obj)

#seurat_obj <- create_test_subset(seurat_obj, num_features = 10000, num_cells = 8000, seed = 42)

seurat_obj <- filter_iterative_sparsity(seurat_obj, cells_cutoff = 0.00003, genes_cutoff = 0.00002)

cotan_obj <- initialize_cotan_from_seurat(
  seurat_obj,
  geo_id = "Arrigoni2023",
  seq_method = "10xv1",
  condition = "prova"
)

cotan_obj <- clean_cotan_data(cotan_obj, cells_cutoff = 0.00003, genes_cutoff = 0.00002)

cotan_obj <- prepare_to_coex(cotan_obj, cores = 80L, chunk_size = 512L)

cotan_obj <- calculate_coex(cotan_obj, return_pp_fract = TRUE, device_str = "cpu")
