# lib_io.R
# Input/Output library for single-cell raw matrix loading

suppressPackageStartupMessages({
  library(Matrix)
  library(Seurat)
})

# Load raw matrix from Seurat RDS file
load_raw_matrix <- function(input_path, input_type = "auto") {
  message("Loading Seurat RDS: ", input_path)
  obj <- readRDS(input_path)
  assay_name <- DefaultAssay(obj)
  if (packageVersion("Seurat") >= "5.0.0") {
    return(GetAssayData(obj, assay = assay_name, layer = "counts"))
  } else {
    return(GetAssayData(obj, assay = assay_name, slot = "counts"))
  }
}
