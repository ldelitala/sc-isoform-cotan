#' Identify Non-Empty Droplets/Cells in a Count Matrix
#'
#' @description
#' An internal helper function that detects which cells (columns) in a count matrix
#' have a total UMI count greater than zero. It uses an ultra-fast evaluation of
#' the column pointers if the matrix is stored as a compressed sparse column
#' matrix (`dgCMatrix`), falling back to a standard column sum for dense matrices.
#'
#' @param counts_mat A matrix containing raw counts. Typically a `dgCMatrix` from
#' a Seurat object slot, but can also accept standard dense matrices.
#'
#' @return A logical vector of length `ncol(counts_mat)`, where `TRUE` indicates
#' the cell contains at least one transcript count, and `FALSE` indicates a
#' completely empty droplet.
#'
#' @importFrom Matrix colSums
#'
#' @examples
#' # Internal usage example:
#' # valid_cells <- not_empty_droplets(GetAssayData(seurat_obj, slot = "counts"))
#' # seurat_filtered <- seurat_obj[, valid_cells]
#'
#'@noRd
.not_empty_droplets <- function(counts_mat) {
    if (inherits(counts_mat, "dgCMatrix")) {
        valid_cells <- diff(counts_mat@p) > 0
    } else {
        # Fallback
        valid_cells <- Matrix::colSums(counts_mat) > 0
    }

    return(valid_cells)
}