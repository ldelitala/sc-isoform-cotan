#' Calculate Cluster Markers for a COTAN Object
#'
#' @description
#' Performs differential expression analysis on clusters and extracts the markers.
#'
#' @param cotan_obj A `COTAN` object with uniform clustering already applied.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_markers.rds"`.
#'
#' @return A list containing the updated `COTAN` object and the cluster markers data.frame.
#'
#' @importFrom COTAN DEAOnClusters findClustersMarkers
#' @import project.base
#' @import project.logger
#' @import deli.cotan.core
#' @import cotan.deli.vis
#' @import deli.seurat
#' @export
calculate_cluster_markers <- function(
  cotan_obj,
  output_dir = NULL,
  file_name = "cotan_markers.rds"
) {
    log_header("Calculating Cluster Markers")

    log_cotan_execution("DEAOnClusters()")
    cotan_obj <- COTAN::DEAOnClusters(cotan_obj)
    log_cotan_execution("DEAOnClusters()", is_complete = TRUE)

    log_cotan_execution("findClustersMarkers()")
    cluster_markers <- COTAN::findClustersMarkers(cotan_obj)
    log_cotan_execution("findClustersMarkers()", is_complete = TRUE)

    log_stat(sprintf("Status: Extracted markers for %d features.", nrow(cluster_markers)))

    if (!is.null(output_dir)) {
        save_object(cotan_obj, output_dir, file_name)
    }

    log_header("Calculating Cluster Markers Complete", is_complete = TRUE)

    return(list(cotan = cotan_obj, markers = cluster_markers))
}
