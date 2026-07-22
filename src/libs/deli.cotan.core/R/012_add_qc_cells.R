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
  log_header("Flag Valid Cells from TSV")

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

  log_header("Valid Cells Flagging Completed", is_complete = TRUE)

  return(new_cotan_obj)
}
