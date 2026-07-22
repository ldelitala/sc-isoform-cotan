#' Create a Toy Subset of a Seurat Object
#'
#' Randomly subsets a Seurat object to a specified number of features and cells,
#' ensuring that no empty droplets (cells with 0 counts for the sampled features)
#' are created in the process.
#'
#' @param seurat_obj A `Seurat` object.
#' @param num_features Integer. Number of random features (transcripts) to retain. Default is 10000.
#' @param num_cells Integer. Number of random cells to retain. Default is 8000.
#' @param seed Integer. Random seed for reproducibility. Default is 42.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"seurat_test_subset.rds"`.
#'
#' @return A randomly subsetted `Seurat` object with no empty droplets.
#'
#' @importFrom SeuratObject Features Cells
#' @importFrom project.base save_object
#' @importFrom project.logger log_header log_info log_warn log_error log_stat
#' @export
create_test_subset <- function(
  seurat_obj,
  num_features = 10000,
  num_cells = 8000,
  seed = 42,
  output_dir = NULL,
  file_name = "seurat_test_subset.rds"
) {
  log_header("create test subset")
  set.seed(seed)

  all_features <- SeuratObject::Features(seurat_obj)
  all_cells <- SeuratObject::Cells(seurat_obj)

  actual_features_to_keep <- min(num_features, length(all_features))

  log_info("Sampling random features...")
  sampled_features <- sample(all_features, actual_features_to_keep)

  log_info("Identifying non-empty cells for the sampled features...")
  valid_cells_logical <- .find_non_empty_cells(seurat_obj, sampled_features)
  valid_cells <- all_cells[valid_cells_logical]

  if (length(valid_cells) == 0) {
    log_error("Fatal: No cells have counts for the randomly sampled features. Try increasing num_features.",
      stop_exec = TRUE
    )
  }

  actual_cells_to_keep <- min(num_cells, length(valid_cells))

  if (actual_cells_to_keep < num_cells) {
    log_warn(sprintf("Only %d valid non-empty cells found (requested %d).", actual_cells_to_keep, num_cells))
  }

  log_info("Sampling random non-empty cells...")
  sampled_cells <- sample(valid_cells, actual_cells_to_keep)

  log_info("Subsetting Seurat object...")
  seurat_subset <- seurat_obj[sampled_features, sampled_cells]

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_subset, output_dir, file_name)
  }

  .log_seurat_change(seurat_obj, seurat_subset)

  log_header(is_complete = TRUE)

  return(seurat_subset)
}


