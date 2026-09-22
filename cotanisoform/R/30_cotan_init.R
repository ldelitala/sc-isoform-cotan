#' Filter COTAN object by a specific condition value
#'
#' @param cotan_obj A COTAN object.
#' @param cond_name Character. The name of the condition (e.g., "passed_QC", "cell_type").
#' @param cond_value Character/Logical. The specific value to retain.
#' @return A COTAN object containing only the cells matching the condition.
#'
#' @importFrom COTAN getCondition getCells dropGenesCells getNumCells getNumGenes
#' @export
filter_cotan_by_condition <- function(cotan_obj, cond_name, cond_value, output_dir = NULL, file_name) {
    log_header("filter cotan by condition")

    new_cotan_obj <- cotan_obj

    log_info("Looking for cells that do not respect the condition...")
    cond_data <- COTAN::getCondition(cotan_obj, condName = cond_name)
    all_cells <- COTAN::getCells(cotan_obj)

    cells_to_drop <- all_cells[is.na(cond_data) | cond_data != cond_value]

    if (length(cells_to_drop) > 0) {
        log_info("Dropping cells...")
        log_cotan_execution("dropGenesCells()")
        new_cotan_obj <- COTAN::dropGenesCells(cotan_obj, cells = cells_to_drop)
        log_cotan_execution("dropGenesCells()", is_complete = TRUE)
    }

    log_stat(sprintf("Condition name: %s", cond_name))
    log_stat(sprintf("Condition value: %s", cond_value))
    log_matrix_stats(
        COTAN::getNumCells(cotan_obj), COTAN::getNumCells(new_cotan_obj),
        COTAN::getNumGenes(cotan_obj), COTAN::getNumGenes(new_cotan_obj)
    )

    if (!is.null(output_dir)) {
      log_info("Saving COTAN object...")
      save_object(cotan_obj, output_dir, file_name)
    }

    log_header(is_complete = TRUE)

    return(new_cotan_obj)
}
#' Initialize COTAN Object from Seurat Object
#'
#' @description
#' Converts a Seurat object into a COTAN object, ensuring metadata is
#' transferred safely.
#'
#' @param seurat_obj A `Seurat` object.
#' @param geo_id String. Identifier for the experiment.
#' @param seq_method String. Sequencing method.
#' @param condition String. Sample condition.
#' @param override Boolean. Silently allows overriding data for an existing condition name. Default is FALSE.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_initialized.rds"`.
#'
#' @return An initialized `COTAN` object.
#'
#' @importFrom Seurat GetAssayData Cells
#' @importFrom COTAN COTAN initializeMetaDataset addCondition getCells getMetadataCells setColumnInDF
#' @importFrom COTAN getNumCells getNumGenes
#'
#' @export
initialize_cotan_from_seurat <- function(
  seurat_obj,
  geo_id,
  seq_method,
  condition,
  override = FALSE,
  output_dir = NULL,
  file_name = "cotan_initialized.rds"
) {
  log_header("initialize cotan from seurat")

  raw_matrix <- GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

  log_info("Checking for non-integer values in counts...")
  if (any(raw_matrix@x %% 1 != 0)) {
    log_error(
      "The count matrix contains decimal values. Run 'round_seurat_counts()' before initializing COTAN.",
      stop_exec = TRUE
    )
  }

  log_info("Creating COTAN object...")

  log_cotan_execution("COTAN()")
  cotan_obj <- COTAN(raw = raw_matrix)
  log_cotan_execution("COTAN()", is_complete = TRUE)


  log_info("Initializing base metadata...")

  log_cotan_execution("initializeMetaDataset()", GEO = geo_id, sequencingMethod = seq_method, sampleCondition = condition)
  cotan_obj <- initializeMetaDataset(
    cotan_obj,
    GEO = geo_id,
    sequencingMethod = seq_method,
    sampleCondition = condition
  )
  log_cotan_execution("initializeMetaDataset()", is_complete = TRUE)


  if (!is.null(output_dir)) {
    log_info("Saving COTAN object...")
    save_object(cotan_obj, output_dir, file_name)
  }

  log_matrix_stats(
    cells_before = COTAN::getNumCells(cotan_obj),
    features_before = COTAN::getNumGenes(cotan_obj)
  )

  log_header(is_complete = TRUE)

  return(cotan_obj)
}
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