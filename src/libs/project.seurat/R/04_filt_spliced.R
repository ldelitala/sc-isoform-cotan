#' Filter Seurat Object to Retain Only Spliced Transcripts
#'
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
#' @importFrom SeuratObject Features
#' @importFrom project.base save_object
#' @importFrom project.logger log_header log_info log_warn log_error log_stat
#' @export
filter_spliced_transcripts <- function(
  seurat_obj,
  prefix = "^ENST",
  output_dir = NULL,
  file_name = "seurat_spliced_filtered.rds"
) {
  log_header("filter spliced transcripts")
  log_info("Filtering features by prefix...")

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
  valid_cells <- .find_non_empty_cells(seurat_obj, spliced_features)
  
  num_cells_before <- ncol(seurat_obj)
  cells_dropped <- num_cells_before - sum(valid_cells)

  if (cells_dropped > 0) {
    log_info("Removing empty cells...")
    seurat_filtered <- seurat_obj[spliced_features, valid_cells]
  } else {
    seurat_filtered <- seurat_obj[spliced_features, ]
  }

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  log_stat(sprintf("Filter prefix: '%s'", prefix))
  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
