#' Round Seurat Raw Counts to Integers
#'
#' @description
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
#' @export
round_seurat_counts <- function(
  seurat_obj,
  assay = "RNA",
  output_dir = NULL,
  file_name = "seurat_rounded_counts.rds"
) {
  log_header("Rounding Seurat Counts")

  log_info(sprintf("Extracting counts from assay '%s'...", assay))
  raw_matrix <- Seurat::GetAssayData(seurat_obj, assay = assay, layer = "counts")

  log_info("Rounding decimal values to integers...")
  raw_matrix@x <- round(raw_matrix@x)

  log_info("Dropping explicit zeros...")
  raw_matrix <- Matrix::drop0(raw_matrix)

  valid_cells <- .not_empty_droplets(raw_matrix)
  num_cells_before <- ncol(raw_matrix)
  cells_dropped <- num_cells_before - sum(valid_cells)

  if (cells_dropped > 0) {
    log_info("Removing cells that became completely empty after rounding...")

    seurat_obj <- seurat_obj[, valid_cells]
    raw_matrix <- raw_matrix[, valid_cells, drop = FALSE]
  }

  log_info("Updating Seurat object with rounded counts...")
  seurat_obj <- Seurat::SetAssayData(
    seurat_obj,
    layer = "counts",
    new.data = raw_matrix,
    assay = assay
  )

  if (!is.null(output_dir)) {
    log_info("Saving Seurat Object...")
    save_object(seurat_obj, output_dir, file_name)
  }

  if (cells_dropped > 0) {
    log_matrix_stats(
      num_cells_before, (num_cells_before - cells_dropped),
      nrow(seurat_obj), nrow(seurat_obj)
    )
  }


  log_header("Rounding Complete", is_complete = TRUE)

  return(seurat_obj)
}
