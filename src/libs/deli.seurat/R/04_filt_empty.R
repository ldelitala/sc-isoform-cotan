#' Filter Seurat Object to Remove Empty Droplets
#'
#' @description
#' Filters out cells from a Seurat object that have zero RNA counts, effectively removing empty
#' droplets from the dataset.
#'
#' @param seurat_obj A `Seurat` object containing single-cell RNA-seq data.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"seurat_no_empty_droplets.rds"`.
#'
#' @return A new `Seurat` object with empty droplets removed.
#' @export
filter_empty_droplets <- function(
  seurat_obj,
  output_dir = NULL,
  file_name = "seurat_no_empty_droplets.rds"
) {
  log_header("Empty Droplet Filtering")

  counts_mat <- GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

  valid_cells <- .not_empty_droplets(counts_mat)

  # Fast Subsetting
  seurat_filtered <- seurat_obj[, valid_cells]

  log_matrix_stats(
    ncol(seurat_obj), ncol(seurat_filtered)
  )

  log_header("Filtering Complete", is_complete = TRUE)

  if (!is.null(output_dir)) {
    save_object(seurat_filtered, output_dir, file_name)
  }

  return(seurat_filtered)
}
