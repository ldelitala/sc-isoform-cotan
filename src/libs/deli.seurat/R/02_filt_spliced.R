#' Filter Seurat Object to Retain Only Spliced Transcripts
#'
#' @description
#' Filters the features of a Seurat object to keep only those that match a specific
#' prefix.
#'
#' @param seurat_obj A `Seurat` object.
#' @param prefix Character string. The regex prefix to match spliced transcripts. Default is "^ENST".
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object.
#'                  Default is `"seurat_spliced_filtered.rds"`.
#'
#' @return A new, filtered `Seurat` object containing only the matched features.
#'
#' @importFrom SeuratObject Features GetAssayData
#' @export
filter_spliced_transcripts <- function(
  seurat_obj,
  prefix = "^ENST",
  output_dir = NULL,
  file_name = "seurat_spliced_filtered.rds"
) {
  log_header("Transcript Type Filtering")
  log_info(sprintf("Retaining only features matching prefix '%s'...", prefix))

  all_features <- SeuratObject::Features(seurat_obj)
  spliced_features <- grep(prefix, all_features, value = TRUE, perl = TRUE)
  num_features_after <- length(spliced_features)

  if (num_features_after == 0) {
    log_error("No features match the provided prefix. Check your matrix row names.", stop_exec = FALSE)
  }

  num_features_before <- length(all_features)
  if (num_features_after < (num_features_before * 0.05)) {
    log_warn(sprintf(
      "Extreme filtering detected. Less than 5%% of features retained. Is the prefix '%s' correct?", prefix
    ))
  }

  log_info("Checking for cells that became empty due to feature removal...")
  counts_mat <- SeuratObject::GetAssayData(seurat_obj, assay = "RNA", layer = "counts")
  valid_cells <- .not_empty_droplets(counts_mat[spliced_features, , drop = FALSE])
  
  num_cells_before <- ncol(seurat_obj)
  cells_dropped <- num_cells_before - sum(valid_cells)

  if (cells_dropped > 0) {
    log_info("Removingcells that became completely empty...")
    seurat_filtered <- seurat_obj[spliced_features, valid_cells]
  } else {
    seurat_filtered <- seurat_obj[spliced_features, ]
  }

  if (!is.null(output_dir)) {
    log_info("Saving Seurat Object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  log_matrix_stats(
    num_cells_before, ncol(seurat_filtered),
    num_features_before, nrow(seurat_filtered)
  )

  log_header("Filtering Complete", is_complete = TRUE)

  return(seurat_filtered)
}
