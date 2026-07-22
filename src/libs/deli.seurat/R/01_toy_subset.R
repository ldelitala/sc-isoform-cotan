#' Create a Toy Subset of a Seurat Object
#'
#' @description
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
#' @importFrom SeuratObject Features Cells GetAssayData
#' @importFrom Matrix colSums
#' @import project.base
#' @import project.logger
#' @export
create_test_subset <- function(
  seurat_obj,
  num_features = 10000,
  num_cells = 8000,
  seed = 42,
  output_dir = NULL,
  file_name = "seurat_test_subset.rds"
) {
  log_header("Creating Test Subset")
  set.seed(seed)

  all_features <- SeuratObject::Features(seurat_obj)
  all_cells <- SeuratObject::Cells(seurat_obj)

  actual_features_to_keep <- min(num_features, length(all_features))

  log_info(sprintf("Sampling %d random features...", actual_features_to_keep))
  sampled_features <- sample(all_features, actual_features_to_keep)

  log_info("Identifying non-empty cells for the sampled features...")
  counts_mat <- SeuratObject::GetAssayData(seurat_obj, assay = "RNA", slot = "counts")[sampled_features, ]

  valid_cells <- all_cells[.not_empty_droplets(counts_mat)]

  if (length(valid_cells) == 0) {
    log_error("Fatal: No cells have counts for the randomly sampled features. Try increasing num_features.",
      stop_exec = TRUE
    )
  }

  actual_cells_to_keep <- min(num_cells, length(valid_cells))

  if (actual_cells_to_keep < num_cells) {
    log_warn(sprintf("Only %d valid non-empty cells found (requested %d).", actual_cells_to_keep, num_cells))
  }

  log_info(sprintf("Sampling %d random non-empty cells...", actual_cells_to_keep))
  sampled_cells <- sample(valid_cells, actual_cells_to_keep)

  log_info("Subsetting Seurat object...")
  # Using bracket notation for the final subset is significantly faster than subset()
  seurat_subset <- seurat_obj[sampled_features, sampled_cells]

  log_info("Subset created successfully.")
  log_stat(sprintf("%d cells", ncol(seurat_subset)))
  log_stat(sprintf("%d features", nrow(seurat_subset)))

  log_matrix_stats(
    length(all_cells), ncol(seurat_subset),
    length(all_features), nrow(seurat_subset)
  )

  if (!is.null(output_dir)) {
    save_object(seurat_subset, output_dir, file_name)
  }

  log_header("Subset Complete", is_complete = TRUE)

  return(seurat_subset)
}
