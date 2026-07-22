#' Round Seurat Raw Counts to Integers
#'
#' Extracts the raw sparse matrix from a Seurat object, rounds all values to the
#' nearest integer, and replaces the assay data.
#'
#' @param seurat_obj A `Seurat` object.
#' @param assay Character. The assay to use. Default is "RNA".
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"seurat_rounded_counts.rds"`.
#'
#' @return A `Seurat` object with strictly integer counts.
#'
#' @importFrom Seurat GetAssayData SetAssayData
#' @importFrom Matrix drop0
#' @importFrom project.base save_object
#' @importFrom project.logger log_header log_info log_warn log_error log_stat
#' @export
round_seurat_counts <- function(
  seurat_obj,
  assay = "RNA",
  output_dir = NULL,
  file_name = "seurat_rounded_counts.rds"
) {
  log_header("round seurat counts")

  log_info("Extracting counts from assay...")
  raw_matrix <- Seurat::GetAssayData(seurat_obj, assay = assay, layer = "counts")

  log_info("Rounding decimal values to integers...")
  raw_matrix@x <- round(raw_matrix@x)

  log_info("Dropping explicit zeros...")
  raw_matrix <- Matrix::drop0(raw_matrix)

  valid_cells <- .not_empty_droplets(raw_matrix)
  num_cells_before <- ncol(raw_matrix)
  cells_dropped <- num_cells_before - sum(valid_cells)

  log_info("Updating Seurat object with rounded counts...")
  seurat_obj <- Seurat::SetAssayData(
    seurat_obj,
    layer = "counts",
    new.data = raw_matrix,
    assay = assay
  )

  seurat_filtered <- seurat_obj
  if (cells_dropped > 0) {
    log_info("Removing cells that became completely empty after rounding...")
    seurat_filtered <- seurat_obj[, valid_cells]
  }

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  log_stat(sprintf("Assay: '%s'", assay))
  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
