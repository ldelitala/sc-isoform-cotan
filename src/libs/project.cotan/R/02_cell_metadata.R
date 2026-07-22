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
#' @import project.logger
#' @import project.utils
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
#' @import project.logger
#' @import project.utils
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
#' @import project.logger
#' @import project.utils
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
