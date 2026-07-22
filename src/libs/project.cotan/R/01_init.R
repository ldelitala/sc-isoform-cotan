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
#' @import project.logger
#' @import project.utils
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
