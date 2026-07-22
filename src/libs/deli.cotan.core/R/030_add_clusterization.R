#' Update or Add a Clusterization in a COTAN Object
#'
#' @description
#' Modifies a COTAN object by adding or updating a specific cell clusterization.
#' It accepts a named vector, separating the data parsing logic from the
#' object manipulation. By setting `override = TRUE`, you can call this
#' function iteratively to append new cell types to the same clusterization.
#' Note: Updating an existing clusterization will automatically reset its
#' associated COEX data.frame (DEA), as the underlying cell groups have changed.
#'
#' @param cotan_obj A `COTAN` object.
#' @param cluster_data A named vector. Names must be cell barcodes, and values are the cluster labels.
#' @param cluster_name Character. Name of the clusterization to add.
#' @param default_value The value assigned to cells not present in `cluster_data` (used only on first creation).
#'                      Defaults to `"Unknown"`.
#' @param strip_suffix Boolean. If TRUE, removes suffixes from barcodes (e.g., '-1') for safer matching.
#'                     Default is TRUE.
#' @param override Boolean. If TRUE, allows updating an existing clusterization. Default is FALSE.
#'
#' @return A `COTAN` object with the updated clusterization.
#'
#' @importFrom COTAN addClusterization getCells getClusterizations getClusters
#' @export
update_cell_clusterization <- function(
  cotan_obj,
  cluster_data,
  cluster_name,
  default_value = "Unknown",
  strip_suffix = TRUE,
  override = FALSE
) {
    log_header("UPDATE CELL CLUSTERIZATION")

    log_info("Retrieving existing clusterizations...")
    cotan_cells <- COTAN::getCells(cotan_obj)
    existing_clusterizations <- tryCatch(COTAN::getClusterizations(cotan_obj), error = function(e) character(0))

    if (cluster_name %in% existing_clusterizations) {
        if (!override) {
            log_error(sprintf("Clusterization '%s' exists. Use override = TRUE to update.", cluster_name), stop_exec = TRUE)
        }
        log_info("Clusterization exists. Updating incrementally (DEA will be reset)...")
        current_clusters <- as.character(COTAN::getClusters(cotan_obj, clName = cluster_name))
    } else {
        log_info("Creating new clusterization...")
        current_clusters <- rep(default_value, length(cotan_cells))
    }

    log_info("Looking for matching barcodes...")
    clean_cotan_cells <- if (strip_suffix) trimws(sub("-.*", "", cotan_cells)) else cotan_cells
    clean_input_barcodes <- if (strip_suffix) trimws(sub("-.*", "", names(cluster_data))) else names(cluster_data)
    match_indices <- match(clean_input_barcodes, clean_cotan_cells)
    valid_matches <- !is.na(match_indices)
    matched_cotan_indices <- match_indices[valid_matches]

    current_clusters[matched_cotan_indices] <- cluster_data[valid_matches]

    current_clusters <- as.factor(current_clusters)

    names(current_clusters) <- cotan_cells

    log_cotan_execution("addClusterization()", clName = cluster_name)

    new_cotan_obj <- COTAN::addClusterization(
        objCOTAN = cotan_obj,
        clName = cluster_name,
        clusters = current_clusters,
        coexDF = data.frame(), # Empty data.frame passed to reset or init DEA slot
        override = TRUE # security check already done previously
    )

    log_cotan_execution("addClusterization()", is_complete = TRUE)
    log_stat(sprintf("Cells updated: %8s", format(length(matched_cotan_indices), big.mark = ",", scientific = FALSE, trim = TRUE)))
    log_header("Clusterization Update Completed", is_complete = TRUE)

    return(new_cotan_obj)
}
