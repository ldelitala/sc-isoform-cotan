#' Update or Add a Condition in a COTAN Object
#'
#' @description
#' Modifies a COTAN object by adding or updating a specific condition.
#' It accepts a named vector, separating the data parsing logic from the
#' object manipulation. By setting `override = TRUE`, you can call this
#' function iteratively to append new data to the same condition.
#'
#' @param cotan_obj A `COTAN` object.
#' @param condition_data A named vector. Names must be cell barcodes, and values are the condition states.
#' @param cond_name Character. Name of the condition to add.
#' @param default_value The value assigned to cells not present in `condition_data` (used only on first creation).
#'                      Defaults to `"Unknown"`.
#' @param strip_suffix Boolean. If TRUE, removes suffixes from barcodes (e.g., '-1') for safer matching.
#'                     Default is TRUE.
#' @param override Boolean. If TRUE, allows updating an existing condition. Default is FALSE.
#'
#' @return A `COTAN` object with the updated condition.
#'
#' @importFrom COTAN addCondition getCells getMetadataCells getNumCells
#' @export
update_cell_condition <- function(
  cotan_obj,
  condition_data,
  cond_name,
  default_value = "Unknown",
  strip_suffix = TRUE,
  override = FALSE
) {
    log_header("update cell condition")

    meta_cells <- tryCatch(COTAN::getMetadataCells(cotan_obj), error = function(e) data.frame())

    if (cond_name %in% colnames(meta_cells)) {
        if (!override) {
            log_error(sprintf("Condition '%s' exists. Use override = TRUE to update.", cond_name), stop_exec = TRUE)
        }
        log_info("Condition exists. Updating incrementally...")
        current_conditions <- meta_cells[[cond_name]]
    } else {
        log_info("Creating new condition...")
        current_conditions <- rep(default_value, getNumCells(cotan_obj))
    }

    if (strip_suffix) log_info("Stripping suffixes...")
    cotan_cells <- COTAN::getCells(cotan_obj)
    clean_cotan_cells <- if (strip_suffix) trimws(sub("-.*", "", cotan_cells)) else cotan_cells
    clean_input_barcodes <- if (strip_suffix) trimws(sub("-.*", "", names(condition_data))) else names(condition_data)
    
    log_info("Finding matching barcodes...")
    match_indices <- match(clean_input_barcodes, clean_cotan_cells)
    valid_matches <- !is.na(match_indices)
    matched_cotan_indices <- match_indices[valid_matches]

    current_conditions[matched_cotan_indices] <- condition_data[valid_matches]

    if (is.character(current_conditions)) {
        current_conditions <- as.factor(current_conditions)
    }

    names(current_conditions) <- cotan_cells

    log_info("Adding Condition...")
    log_cotan_execution("addCondition()", condName = cond_name)

    new_cotan_obj <- COTAN::addCondition(
        cotan_obj,
        condName = cond_name,
        conditions = current_conditions,
        override = TRUE # security check already done previously
    )

    log_cotan_execution("addCondition()", is_complete = TRUE)
    log_stat(sprintf("Cells updated: %8s", format(length(matched_cotan_indices), big.mark = ",", scientific = FALSE, trim = TRUE)))
    log_header(is_complete = TRUE)

    return(new_cotan_obj)
}

#' Add Origin Sample Condition to COTAN Object
#'
#' @description
#' Maps cell barcodes to their original sample names using a TSV file,
#' and registers them as the "origin" condition inside the COTAN object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param b2sample_tsv Character. Path to a TSV file mapping barcodes to original sample names.
#' @param override Boolean. If TRUE, overrides an existing "origin" condition. Default is FALSE.
#'
#' @return A `COTAN` object with the "origin" condition added.
#' @export
add_origin_samples <- function(
  cotan_obj,
  b2sample_tsv = NULL,
  override = FALSE
) {
  log_header("add origin samples")

  if (is.null(b2sample_tsv)) {
    log_error("Please provide a b2sample.tsv file", stop_exec = TRUE)
  }

  log_info("Getting mapping vector...")
  mapping_vec <- get_mapping_vector(b2sample_tsv, has_header = TRUE)

  log_info("Updating cell condition...")
  new_cotan_obj <- update_cell_condition(
    cotan_obj = cotan_obj,
    condition_data = mapping_vec,
    cond_name = "origin",
    default_value = "Unknown",
    override = override
  )

  log_header(is_complete = TRUE)

  return(new_cotan_obj)
}

#' Flag Valid Cells from a TSV File
#'
#' @description
#' Reads a list of valid barcodes from a TSV file (e.g., cells that passed QC),
#' standardizes the barcode formats, and registers their valid status as a
#' condition in the COTAN object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param tsv_file Character. Path to the TSV file.
#' @param cond_name Character. Name of the condition. Default is `"passed_QC"`.
#' @param has_header Boolean. Set to TRUE if the TSV file has a header row. Default is TRUE.
#' @param override Boolean. If TRUE, overrides an existing condition. Default is FALSE.
#'
#' @return A `COTAN` object with the QC condition added.
#' @export
flag_valid_cells_from_tsv <- function(
  cotan_obj,
  tsv_file,
  cond_name = "passed_QC",
  has_header = TRUE,
  override = FALSE
) {
  log_header("flag valid cells from tsv")

  log_info("Getting flagging vector...")
  valid_vec <- get_uniform_vector(tsv_file, has_header = has_header)

  log_info("Updating cell condition...")
  new_cotan_obj <- update_cell_condition(
    cotan_obj = cotan_obj,
    condition_data = valid_vec,
    cond_name = cond_name,
    default_value = FALSE,
    override = override
  )

  log_header(is_complete = TRUE)

  return(new_cotan_obj)
}
#' Add a new column to the metaGenes data.frame
#'
#' @param cotan_obj A COTAN object.
#' @param col_name Character. The name of the new column to add.
#' @param col_data A named vector. The names must match the transcripts/genes in the object.
#' @return The updated COTAN object.
#'
#' @importFrom COTAN getMetadataGenes getGenes setColumnInDF
#' @export
add_genes_metadata <- function(cotan_obj, col_name, col_data) {
    log_header("add genes metadata")

    all_transcripts <- COTAN::getGenes(cotan_obj)

    if (!is.null(names(col_data))) {
        log_info("Aligning data to transcripts...")
        aligned_data <- col_data[all_transcripts]

        num_nas <- sum(is.na(aligned_data))
        if (num_nas > 0) {
            log_warn(sprintf("Found %d missing values (NAs) after aligning data to transcripts.", num_nas))
        }
    } else {
        if (length(col_data) != length(all_transcripts)) {
            log_error(
                sprintf(
                    "Length mismatch: col_data has %d elements, but there are %d transcripts.",
                    length(col_data), length(all_transcripts)
                ),
                stop_exec = TRUE
            )
        }
        aligned_data <- col_data
    }

    log_info("Setting column in metadata dataframe...")
    log_cotan_execution("setColumnInDF()", colName = col_name)

    genes_metadata <- COTAN::setColumnInDF(
        df = COTAN::getMetadataGenes(cotan_obj),
        colToSet = aligned_data,
        colName = col_name,
        rowNames = all_transcripts
    )

    cotan_obj@metaGenes <- genes_metadata

    log_cotan_execution("setColumnInDF()", is_complete = TRUE)
    log_stat(sprintf("Transcripts targeted: %8s", format(length(all_transcripts), big.mark = ",", scientific = FALSE, trim = TRUE)))
    log_header(is_complete = TRUE)
    
    return(cotan_obj)
}

#' Map transcripts to genes using a t2g file
#'
#' @param cotan_obj A COTAN object (transcript-level).
#' @param t2g_file Character. Path to the t2g mapping file.
#' @param has_header Boolean. TRUE if the file has a header. Default is FALSE.
#' @param col_name Character. The name of the new column in metaGenes. Default is "gene_id".
#' @return The updated COTAN object.
#'
#' @export
add_gene_info_from_t2g <- function(cotan_obj, t2g_file, has_header = FALSE, col_name = "gene_id") {
    log_header("add gene info from t2g")

    if (is.null(t2g_file)) {
        log_error("Please provide a t2g.tsv file", stop_exec = TRUE)
    }

    log_info("Getting mapping vector...")
    gene_mapping <- get_mapping_vector(t2g_file, has_header = has_header)

    log_info("Adding genes metadata...")
    cotan_obj <- add_genes_metadata(
        cotan_obj = cotan_obj,
        col_name = col_name,
        col_data = gene_mapping
    )
    log_header(is_complete = TRUE)

    return(cotan_obj)
}
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
    log_header("update cell clusterization")

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
    log_header(is_complete = TRUE)

    return(new_cotan_obj)
}

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
  log_header("add cell types from tsv")

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

  log_header(is_complete = TRUE)

  return(new_cotan_obj)
}