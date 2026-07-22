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
  log_header("ADD ORIGIN SAMPLE")

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

  log_header("Adding sample of origin complete", is_complete = TRUE)

  return(new_cotan_obj)
}
