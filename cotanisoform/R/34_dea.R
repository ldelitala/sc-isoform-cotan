

#' Run DEA on Clusters and Store in COTAN Object
#'
#' @param cotan_obj A `COTAN` object.
#' @param cl_name Character. Name of the clusterization.
#' @param clusters A clusterization vector. If NULL, retrieves existing clusters. Default is NULL.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_dea.rds"`.
#' @return A `COTAN` object with DEA results stored in the clusterization slot.
#' @importFrom COTAN DEAOnClusters addClusterization getClusters
#' @export
dea_on_clusters <- function(
  cotan_obj,
  cl_name,
  clusters = NULL,
  output_dir = NULL,
  file_name = "cotan_dea.rds"
) {
    log_header("dea on clusters")
    log_cotan_execution("DEAOnClusters()", clName = cl_name)

    # Run DEA with optional clusters parameter
    dea_df <- COTAN::DEAOnClusters(cotan_obj, clName = cl_name, clusters = clusters)
    log_cotan_execution("DEAOnClusters()", is_complete = TRUE)

    # Determine clusters to use for storage
    use_clusters <- if (is.null(clusters)) {
        COTAN::getClusters(cotan_obj, clName = cl_name)
    } else {
        clusters
    }

    # Store it back in the clusterization
    cotan_obj <- COTAN::addClusterization(
        objCOTAN = cotan_obj,
        clName = cl_name,
        clusters = use_clusters,
        coexDF = dea_df,
        override = TRUE
    )

    if (!is.null(output_dir)) {
        log_info("Saving COTAN object...")
        save_object(cotan_obj, output_dir, file_name)
    }

    log_header(is_complete = TRUE)
    return(cotan_obj)
}
