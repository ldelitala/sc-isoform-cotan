#' Generate Pseudo-bulk Transcript Counts
#'
#' @description
#' Aggregates single-cell counts by summing across cells within each cluster/cell type
#' to generate a pseudo-bulk count matrix. Useful for running baseline DTU methods.
#'
#' @param seurat_obj A `Seurat` object.
#' @param cluster_col Character. The metadata column name containing cluster/cell type labels.
#' @param assay Character. The assay to extract counts from. Default is `"RNA"`.
#'
#' @return A dense matrix where rows are transcripts and columns are clusters.
#'
#' @importFrom Seurat GetAssayData
#' @importFrom Matrix rowSums
#' @export
generate_pseudobulk <- function(seurat_obj, cluster_col, assay = "RNA") {
    log_header("Generating Pseudo-bulk Counts")

    if (!cluster_col %in% colnames(seurat_obj@meta.data)) {
        log_error(sprintf("Cluster column '%s' not found in Seurat metadata.", cluster_col), stop_exec = TRUE)
    }

    counts_mat <- Seurat::GetAssayData(seurat_obj, assay = assay, layer = "counts")
    clusters <- as.character(seurat_obj@meta.data[[cluster_col]])

    unique_clusters <- unique(clusters)
    log_stat(sprintf("Aggregating across %d unique clusters...", length(unique_clusters)))

    # Fast column aggregation for sparse matrices
    pb_list <- lapply(unique_clusters, function(cl) {
        cells_in_cl <- which(clusters == cl)
        if (length(cells_in_cl) == 1) {
            return(as.vector(counts_mat[, cells_in_cl]))
        } else {
            return(as.vector(Matrix::rowSums(counts_mat[, cells_in_cl])))
        }
    })

    pb_matrix <- do.call(cbind, pb_list)
    colnames(pb_matrix) <- unique_clusters
    rownames(pb_matrix) <- rownames(counts_mat)

    log_header("Pseudo-bulk Generation Complete", is_complete = TRUE)

    return(pb_matrix)
}
