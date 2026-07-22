#' Subset COTAN Object by Cells
#'
#' @description
#' Subsets a COTAN object to keep only a specific set of cells.
#' Under the hood, this uses the native `COTAN::dropGenesCells` function
#' to safely drop the unneeded cells, ensuring that metadata is preserved
#' and calculated estimators are reset for the subset.
#'
#' @param cotan_obj A `COTAN` object.
#' @param cells_to_keep A character vector of cell barcodes to retain.
#'
#' @return A new `COTAN` object containing only the specified cells.
#'
#' @importFrom COTAN getCells dropGenesCells
#' @import project.base
#' @import project.logger
#' @export
subset_cotan_by_cells <- function(cotan_obj, cells_to_keep) {
  log_header("Subsetting COTAN Object by Cells")
  all_cells <- getCells(cotan_obj)

  # Check if all requested cells exist
  invalid_cells <- setdiff(cells_to_keep, all_cells)
  if (length(invalid_cells) > 0) {
    log_warn(sprintf(
      "%d cells requested for subsetting do not exist in the COTAN object. Proceeding without them.",
      length(invalid_cells)
    ))
    cells_to_keep <- intersect(cells_to_keep, all_cells)
  }

  if (length(cells_to_keep) == 0) {
    log_error("No valid cells to keep in the subset. Cannot proceed.", stop_exec = TRUE)
  }

  cells_to_drop <- setdiff(all_cells, cells_to_keep)

  if (length(cells_to_drop) == 0) {
    log_info("All cells are retained. Returning the original object.")
    log_header("Subsetting Complete (No Change)", is_complete = TRUE)
    return(cotan_obj)
  }

  log_info(sprintf("Dropping %d cells to retain %d cells...", length(cells_to_drop), length(cells_to_keep)))

  log_cotan_execution("dropGenesCells()")
  subset_obj <- dropGenesCells(cotan_obj, cells = cells_to_drop)
  log_cotan_execution("dropGenesCells()", is_complete = TRUE)

  log_stat(sprintf("Final cells count: %d", length(getCells(subset_obj))))
  log_header("Subsetting Complete", is_complete = TRUE)

  return(subset_obj)
}
