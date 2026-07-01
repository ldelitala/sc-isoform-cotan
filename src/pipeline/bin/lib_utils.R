#!/usr/bin/env Rscript

library(Seurat)

#' Filter Seurat Object by Mitochondrial Transcript Percentage
#'
#' @description
#' Calculates the percentage of mitochondrial counts per cell using custom list
#' of transcript IDs, and filters out cells exceeding a specified threshold.
#'
#' @param seurat_obj A `Seurat` object containing single-cell RNA-seq data.
#' @param mt_transcripts_list A character vector containing transcript IDs.
#' @param threshold Numeric. Maximum acceptable MT percentage. Default is 5.
#'
#' @return A new, filtered `Seurat` object.
#'
#' @export
filter_mt_transcripts <-
  function(seurat_obj, mt_transcripts_list, threshold = 5) {
    # Intersect ensures we only use transcripts actually present in the matrix
    valid_mt <- intersect(mt_transcripts_list, rownames(seurat_obj))

    # Calculate MT percentage and store it in metadata
    seurat_obj[["percent.mt"]] <- PercentageFeatureSet(
      seurat_obj,
      features = valid_mt,
      assay = "RNA"
    )

    # Filter the object based on the threshold
    subset(
      seurat_obj,
      subset = percent.mt < threshold
    )
  }

#' Round and Convert Sparse Matrix Values to Integer
#'
#' @description
#' Rounds the non-zero values of a sparse matrix and explicitly converts 
#' them to the integer data type required by COTAN.
#'
#' @param raw_matrix A sparse matrix (e.g., dgCMatrix) with fractional counts.
#'
#' @return A sparse matrix of the same dimensions, with integer values.
#'
#' @export
round_sparse_matrix <- function(raw_matrix) {

  raw_matrix@x <- as.integer(round(raw_matrix@x))

  if (is.integer(raw_matrix@x)) {
    message("SUCCESS: Matrix values safely converted to integers.")
  } else {
    warning("ERROR: Matrix values are not integers.")
  }

  raw_matrix
}

config_cotan_workflow(
  output_dir = "./results",
  log_file_name = "filter_mt_transcripts.log"
)

# 1. Estrai la matrice filtrata pulita
clean_raw_matrix <-
  GetAssayData(seurat_obj_filtered, assay = "RNA", layer = "counts")

# 2. Round and convert the sparse matrix values to integers
clean_raw_matrix <- round_sparse_matrix(clean_raw_matrix)

# 2. Inizializza direttamente l'oggetto COTAN
obj_cotan <- COTAN(raw = clean_raw_matrix)

# 3. Trasferisci i metadati utili (come la tua percentuale mitocondriale)
colData(obj_cotan)$percent.mt <- seurat_obj_filtered$percent.mt

# 4. Inizia il workflow nativo di COTAN
obj_cotan <-
  initializeMetaDataset(
    obj_cotan,
    GEO = "Arrigoni2023",
    sequencingMethod = "10XV1",
    sampleCondition = "Controllo"
  )
