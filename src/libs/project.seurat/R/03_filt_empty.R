#' Filter Seurat Object to Remove Empty Droplets
#'
#' Filters out cells from a Seurat object that have zero RNA counts, effectively removing empty
#' droplets from the dataset.
#'
#' @param seurat_obj A `Seurat` object containing single-cell RNA-seq data.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"seurat_no_empty_droplets.rds"`.
#'
#' @return A new `Seurat` object with empty droplets removed.
#'
#' @importFrom Seurat GetAssayData
#' @importFrom project.base save_object
#' @importFrom project.logger log_header log_info log_warn log_error log_stat
#' @export
filter_empty_droplets <- function(
  seurat_obj,
  output_dir = NULL,
  file_name = "seurat_no_empty_droplets.rds"
) {
  log_header("filter empty droplets")

  counts_mat <- Seurat::GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

  log_info("Identifying non-empty droplets...")
  valid_cells <- .not_empty_droplets(counts_mat)

  # Fast Subsetting
  log_info("Subsetting Seurat object...")
  seurat_filtered <- seurat_obj[, valid_cells]

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
