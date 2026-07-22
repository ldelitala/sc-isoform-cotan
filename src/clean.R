#!/usr/bin/env Rscript

library(Seurat)
library(Matrix)

# 0. temp hardcoding of paths
combined_raw_matrix_path <- 
  "/data/lorenzo_delitala/runs/arrigoni2023/results/combined_raw_matrix.seurat.rds" # nolint: line_length_linter.

seurat_obj <- readRDS(combined_raw_matrix_path)

# 1. Extract the matrix (which contains the EM fractional counts)
raw_matrix <- GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

# 2. Round ONLY the non-zero values directly in the memory slot
# This preserves the sparse matrix structure and uses almost zero RAM
raw_matrix@x <- round(raw_matrix@x)

# 3. Run a quick validation to ensure it worked
if (all(raw_matrix@x %% 1 == 0)) {
  message("SUCCESS: The matrix has been safely rounded to integers.")
} else {
  message("ERROR: Rounding failed.")
}