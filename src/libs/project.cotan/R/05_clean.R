#' Clean COTAN Object
#'
#' @description
#' Applies the basic COTAN clean() method to remove sparse genes and cells.
#' It finds fully-expressed genes and fully-expressing cells,
#' returns the given COTAN object with updated fully-expressed genes' information
#' Mitochondrial filtering is assumed to be handled prior to this step.
#'
#' @param cotan_obj A `COTAN` object.
#' @param cells_cutoff Numeric. Fraction of cells a gene must be expressed in to be kept (Default 0.003).
#' @param genes_cutoff Numeric. Fraction of genes a cell must express to be kept (Default 0.002).
#' @param cells_threshold Numeric. Genes expressed in > fraction of cells marked as fully-expressed (Default 0.99).
#' @param genes_threshold Numeric. Cells expressing > fraction of genes marked as fully-expressing (Default 0.99).
#' @param drop_fully_expressed Logical. Whether to physically drop fully-expressed genes/transcripts from the object. Default is `FALSE`.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_cleaned.rds"`.
#'
#' @return A cleaned `COTAN` object with updated `nu` estimators.
#'
#' @importFrom COTAN clean getNumCells getNumGenes getFullyExpressedGenes dropGenesCells
#' @import project.logger
#' @import project.utils
#' @export
clean_cotan_data <- function(
  cotan_obj,
  cells_cutoff = 0.003,
  genes_cutoff = 0.002,
  cells_threshold = 0.99,
  genes_threshold = 0.99,
  drop_fully_expressed = FALSE,
  output_dir = NULL,
  file_name = "cotan_cleaned.rds"
) {
    log_header("clean cotan data")

    num_cells_before <- getNumCells(cotan_obj)
    num_genes_before <- getNumGenes(cotan_obj)

    log_cotan_execution("clean()",
      cellsCutoff = cells_cutoff, genesCutoff = genes_cutoff,
      cellsThreshold = cells_threshold, genesThreshold = genes_threshold
    )
    
    cotan_obj <- clean(
      cotan_obj,
      cellsCutoff = cells_cutoff,
      genesCutoff = genes_cutoff,
      cellsThreshold = cells_threshold,
      genesThreshold = genes_threshold
    )
    log_cotan_execution("clean()", is_complete = TRUE)

    # If requested, physically remove fully-expressed genes/transcripts
    if (drop_fully_expressed) {
      log_info("Identifying and dropping fully-expressed genes/transcripts...")
      fully_expressed <- getFullyExpressedGenes(cotan_obj)
      
      if (length(fully_expressed) > 0) {
        log_info(sprintf("Found %d fully-expressed genes/transcripts. Dropping them...", length(fully_expressed)))
        cotan_obj <- dropGenesCells(cotan_obj, genes = fully_expressed)
      } else {
        log_info("No fully-expressed genes found to drop.")
      }
    }

    num_cells_after <- getNumCells(cotan_obj)
    num_genes_after <- getNumGenes(cotan_obj)

    if (num_cells_after == 0 || num_genes_after == 0) {
      log_error("The clean() method removed ALL cells or ALL genes. Check your cutoff parameters.", stop_exec = TRUE)
    }

    if (num_cells_after < (num_cells_before * 0.2)) {
      log_warn("Warning: cleaning removed over 80% of the cells. The parameters might be too restrictive.")
    }
    
    if (!is.null(output_dir)) {
      log_info("Saving COTAN object...")
      save_object(cotan_obj, output_dir, file_name)
    }

    log_matrix_stats(
      num_cells_before, num_cells_after,
      num_genes_before, num_genes_after
    )

    log_header(is_complete = TRUE)

    return(cotan_obj)
}