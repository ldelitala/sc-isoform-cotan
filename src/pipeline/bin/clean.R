#!/usr/bin/env Rscript

# FILE NAME: clean.R

library(Seurat)
library(Matrix)

# 0. temp hardcoding of paths
output_dir <- "./results/cotan_data"
log_file_name <- "clean.log"
combined_raw_matrix_path = "/data/lorenzo_delitala/runs/arrigoni2023/results/combined_raw_matrix.seurat.rds"

# source("/data/lorenzo_delitala/src/pipeline/bin/lib_COTAN_config.R")

# config_cotan_workflow(output_dir, log_file_name)

# Assuming you already loaded your Seurat object
seurat_obj <- readRDS(combined_raw_matrix_path)

# 1. Extract the matrix (which contains the EM fractional counts)
raw_matrix <- GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

# 2. Round ONLY the non-zero values directly in the memory slot
# This preserves the sparse matrix structure and uses almost zero RAM
raw_matrix@x <- round(raw_matrix@x)

# 3. Run a quick validation to ensure it worked
is_integer <- all(raw_matrix@x %% 1 == 0)

if (is_integer) {
  message("SUCCESS: The matrix has been safely rounded to integers.")
} else {
  message("ERROR: Rounding failed.")
}