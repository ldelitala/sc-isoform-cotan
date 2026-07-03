#!/usr/bin/env Rscript

library(Seurat)
library(Matrix)
library(COTAN)
library(SummarizedExperiment)

#' Filter Seurat Object by Mitochondrial Transcript Percentage
#'
#' @description
#' Calculates the percentage of mitochondrial counts per cell using a custom
#' list of transcript IDs and filters out cells exceeding a specified threshold.
#'
#' @param seurat_obj A `Seurat` object containing single-cell RNA-seq data.
#' @param mt_transcripts_list A character vector containing transcript IDs.
#' @param threshold Numeric. Maximum acceptable MT percentage. Default is 5.
#'
#' @return A new, filtered `Seurat` object.
#'
#' @export
filter_mt_transcripts <- function(seurat_obj, mt_transcripts_list,
                                  threshold = 5) {
  message("\n--- Starting Mitochondrial Filtering ---")

  valid_mt <- base::intersect(mt_transcripts_list, rownames(seurat_obj))
  message(sprintf(
    "Found %d valid mitochondrial transcripts.",
    length(valid_mt)
  ))

  seurat_obj[["percent.mt"]] <- PercentageFeatureSet(
    seurat_obj,
    features = valid_mt,
    assay = "RNA"
  )

  cells_before <- ncol(seurat_obj)

  seurat_filtered <- subset(seurat_obj, subset = percent.mt < threshold)
  cells_after <- ncol(seurat_filtered)

  message(sprintf(
    "Removed %d cells exceeding the %s%% threshold.",
    (cells_before - cells_after), threshold
  ))
  message(sprintf("Remaining cells: %d", cells_after))
  message("----------------------------------------\n")

  return(seurat_filtered)
}

#' Initialize COTAN Object from Filtered Seurat Object
#'
#' @description
#' Converts a filtered Seurat object into a COTAN object, ensuring counts are
#' properly rounded to integers and metadata (like percent.mt) is transferred.
#'
#' @param seurat_obj A filtered `Seurat` object.
#' @param geo_id String. Identifier for the experiment.
#' @param seq_method String. Sequencing method (e.g., "10XV1").
#' @param condition String. Sample condition (e.g., "Control").
#'
#' @return An initialized `COTAN` object.
#'
#' @importFrom Seurat GetAssayData
#' @importFrom COTAN COTAN initializeMetaDataset
#' @export
initialize_cotan_from_seurat <- function(seurat_obj, geo_id,
                                         seq_method = "10XV1", condition) {
  message("--- Initializing COTAN Pipeline ---")

  message("[1/4] Extracting raw counts from Seurat object...")
  raw_matrix <- GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

  message("[2/4] Rounding decimal values to integers (Sparse Matrix)...")
  raw_matrix@x <- round(raw_matrix@x)

  message("[3/4] Creating COTAN object and computing base metrics...")
  cotan_obj <- COTAN(raw = raw_matrix)

  cotan_obj <- initializeMetaDataset(
    cotan_obj,
    GEO = geo_id,
    sequencingMethod = seq_method,
    sampleCondition = condition
  )

  message("[4/4] Safely transferring 'percent.mt' metadata...")

  cotan_cells <- rownames(cotan_obj@metaCells)
  seurat_cells <- colnames(seurat_obj)
  mt_data <- seurat_obj@meta.data$percent.mt

  matched_indices <- match(cotan_cells, seurat_cells)
  cotan_obj@metaCells$percent.mt <-
    mt_data[matched_indices]

  message("SUCCESS: COTAN object successfully initialized and ready!")
  message("----------------------------------------\n")

  return(cotan_obj)
}
