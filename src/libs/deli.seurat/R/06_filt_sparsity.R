#' Iteratively Filter Sparse Matrix in Seurat Object
#'
#' @description
#' Extracts the raw sparse matrix from a Seurat object and iteratively applies
#' cutoffs for minimum expressing cells per gene and minimum expressed genes per cell.
#' It loops on the dgCMatrix until convergence (zero features or cells dropped).
#'
#' @param seurat_obj A `Seurat` object.
#' @param cells_cutoff Numeric. Fraction of cells a feature must be expressed in. Default is 0.003.
#' @param genes_cutoff Numeric. Fraction of features a cell must express. Default is 0.002.
#' @param loss_threshold Numeric. Threshold (0-1) to trigger a warning for data loss. Default is 0.5 (50%).
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"seurat_sparsity_filtered.rds"`.
#'
#' @return A new, subsetted `Seurat` object with the converged dimensions.
#'
#' @importFrom Seurat GetAssayData
#' @importFrom Matrix drop0
#' @export
filter_iterative_sparsity <- function(
  seurat_obj,
  cells_cutoff = 0.003,
  genes_cutoff = 0.002,
  loss_threshold = 0.5,
  output_dir = NULL,
  file_name = "seurat_sparsity_filtered.rds"
) {
  log_header("Iterative Sparsity Filtering")

  log_stat(sprintf("Cells cutoff: %f", cells_cutoff))
  log_stat(sprintf("Genes cutoff: %f", genes_cutoff))

  raw_mat <- Seurat::GetAssayData(seurat_obj, assay = "RNA", layer = "counts")
  raw_mat <- Matrix::drop0(raw_mat)

  initial_features <- nrow(raw_mat)
  initial_cells <- ncol(raw_mat)

  converged <- FALSE
  iteration <- 1

  while (!converged) {
    log_info(sprintf("Iteration %d...", iteration))
    start_genes <- nrow(raw_mat)
    start_cells <- ncol(raw_mat)

    # Filter genes
    absolute_gene_cutoff <- round(start_cells * cells_cutoff, digits = 0L)
    expressing_cells <- tabulate(raw_mat@i + 1L, nbins = start_genes)
    raw_mat <- raw_mat[expressing_cells > absolute_gene_cutoff, , drop = FALSE]

    # Filter cells
    absolute_cell_cutoff <- round(nrow(raw_mat) * genes_cutoff, digits = 0L)
    expressed_genes <- diff(raw_mat@p)
    raw_mat <- raw_mat[, expressed_genes > absolute_cell_cutoff, drop = FALSE]

    end_genes <- nrow(raw_mat)
    end_cells <- ncol(raw_mat)

    if (end_genes == 0 || end_cells == 0) {
      log_error(
        "Iterative filtering removed ALL cells or ALL features. Reduce the cells_cutoff or genes_cutoff values.",
        stop_exec = TRUE
      )
    }

    log_info(sprintf("Iteration %d finished.", iteration))
    log_matrix_stats(
      start_cells, end_cells,
      start_genes, end_genes
    )

    if ((start_genes - end_genes) == 0 && (start_cells - end_cells) == 0) {
      converged <- TRUE
    } else {
      iteration <- iteration + 1
    }
  }

  final_features <- nrow(raw_mat)
  final_cells <- ncol(raw_mat)

  feature_loss_ratio <- (initial_features - final_features) / initial_features
  cell_loss_ratio <- (initial_cells - final_cells) / initial_cells

  if (feature_loss_ratio > loss_threshold) {
    log_warn(sprintf("High feature loss detected! Removed %.1f%% of total features.", feature_loss_ratio * 100))
  }

  if (cell_loss_ratio > loss_threshold) {
    log_warn(sprintf("High cell loss detected! Removed %.1f%% of total cells.", cell_loss_ratio * 100))
  }

  log_info("Filtering converged.")
  log_matrix_stats(
    initial_cells, final_cells,
    initial_features, final_features
  )

  valid_features <- rownames(raw_mat)
  valid_cells <- colnames(raw_mat)

  log_info("Updating Seurat Object...")
  seurat_filtered <- subset(seurat_obj, features = valid_features, cells = valid_cells)

  log_header("Filtering Complete", is_complete = TRUE)

  if (!is.null(output_dir)) {
    save_object(seurat_filtered, output_dir, file_name)
  }

  return(seurat_filtered)
}
