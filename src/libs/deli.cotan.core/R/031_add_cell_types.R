#' Add Cell Types From Multiple TSV/TVS Files
#'
#' @description
#' Reads barcodes from multiple TSV/TVS files (one file per cell type),
#' extracts the named vectors, and delegates the standardization and insertion 
#' to the `update_cell_clusterization` helper to register them as a 
#' clusterization inside the COTAN object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param tsv_files A named character vector or list of file paths.
#' @param cluster_name Character. Name of the clusterization to add. Default is `"Known_Cell_Types"`.
#' @param override Boolean. If TRUE, overrides or updates an existing clusterization. Default is FALSE.
#'
#' @return A `COTAN` object with the cell type clusterization added.
#' @export
add_cell_types_from_tsv <- function(
  cotan_obj,
  tsv_files,
  cluster_name = "Known_Cell_Types",
  override = FALSE
) {
  log_header("Add Cell Types from TSV")

  combined_cluster_data <- c()

  log_info("Getting vectors...")
  for (cell_type in names(tsv_files)) {
    file_path <- tsv_files[[cell_type]]

    type_vec <- get_uniform_vector(file_path, value = cell_type, has_header = FALSE)

    combined_cluster_data <- c(combined_cluster_data, type_vec)
  }

  log_info("Updating cell clusterization...")
  
  new_cotan_obj <- update_cell_clusterization(
    cotan_obj = cotan_obj,
    cluster_data = combined_cluster_data,
    cluster_name = cluster_name,
    default_value = "Unknown",
    strip_suffix = TRUE, 
    override = override
  )

  log_header("Cell Types Added Successfully", is_complete = TRUE)

  return(new_cotan_obj)
}