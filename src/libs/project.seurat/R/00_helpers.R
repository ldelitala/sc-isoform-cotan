# ==============================================================================
# Internal Helper Functions
# ==============================================================================

#' Identify Non-Empty Droplets/Cells in a Count Matrix
#'
#' @param counts_mat A matrix containing raw counts (typically dgCMatrix or dense).
#' @return A logical vector of length `ncol(counts_mat)`.
#' @noRd
.not_empty_droplets <- function(counts_mat) {
    if (inherits(counts_mat, "dgCMatrix")) {
        valid_cells <- diff(counts_mat@p) > 0
    } else {
        valid_cells <- Matrix::colSums(counts_mat) > 0
    }
    return(valid_cells)
}

#' Identify Cells with Non-Zero Expression for a Subset of Features
#'
#' Evaluates column pointers directly for `dgCMatrix` to avoid memory copies.
#'
#' @param seurat_obj A `Seurat` object.
#' @param features Character vector of features to evaluate.
#' @param assay Character. The assay to query. Default is "RNA".
#' @param layer Character. The layer to query. Default is "counts".
#' @return A logical vector of length `ncol(seurat_obj)`.
#' @noRd
.find_non_empty_cells <- function(seurat_obj, features, assay = "RNA", layer = "counts") {
    counts_mat <- Seurat::GetAssayData(seurat_obj, assay = assay, layer = layer)
    
    if (inherits(counts_mat, "dgCMatrix")) {
        subset_mat <- counts_mat[rownames(counts_mat) %in% features, , drop = FALSE]
        valid_cells <- diff(subset_mat@p) > 0
    } else {
        # Fallback for dense matrices
        valid_cells <- Matrix::colSums(counts_mat[features, , drop = FALSE]) > 0
    }
    
    return(valid_cells)
}

#' Log Variation/Change in Seurat Object Dimensions
#'
#' Wrapper around `log_matrix_stats` to easily display filtering progression.
#'
#' @param before_obj The `Seurat` object before filtering.
#' @param after_obj The `Seurat` object after filtering.
#' @param level Integer. Log level threshold. Default is 1L.
#' @noRd
.log_seurat_change <- function(before_obj, after_obj, level = 1L) {
    log_matrix_stats(
        cells_before = ncol(before_obj),
        cells_after = ncol(after_obj),
        features_before = nrow(before_obj),
        features_after = nrow(after_obj),
        level = level
    )
}
