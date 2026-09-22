#' Filter COTAN object by a specific condition value
#'
#' @param cotan_obj A COTAN object.
#' @param cond_name Character. The name of the condition (e.g., "passed_QC", "cell_type").
#' @param cond_value Character/Logical. The specific value to retain.
#' @return A COTAN object containing only the cells matching the condition.
#'
#' @importFrom COTAN getCondition getCells dropGenesCells getNumCells getNumGenes
#' @import project.logger
#' @import project.utils
#' @export
filter_cotan_by_condition <- function(cotan_obj, cond_name, cond_value, output_dir = NULL, file_name) {
    log_header("filter cotan by condition")

    new_cotan_obj <- cotan_obj

    log_info("Looking for cells that do not respect the condition...")
    cond_data <- COTAN::getCondition(cotan_obj, condName = cond_name)
    all_cells <- COTAN::getCells(cotan_obj)

    cells_to_drop <- all_cells[is.na(cond_data) | cond_data != cond_value]

    if (length(cells_to_drop) > 0) {
        log_info("Dropping cells...")
        log_cotan_execution("dropGenesCells()")
        new_cotan_obj <- COTAN::dropGenesCells(cotan_obj, cells = cells_to_drop)
        log_cotan_execution("dropGenesCells()", is_complete = TRUE)
    }

    log_stat(sprintf("Condition name: %s", cond_name))
    log_stat(sprintf("Condition value: %s", cond_value))
    log_matrix_stats(
        COTAN::getNumCells(cotan_obj), COTAN::getNumCells(new_cotan_obj),
        COTAN::getNumGenes(cotan_obj), COTAN::getNumGenes(new_cotan_obj)
    )

    if (!is.null(output_dir)) {
      log_info("Saving COTAN object...")
      save_object(cotan_obj, output_dir, file_name)
    }

    log_header(is_complete = TRUE)

    return(new_cotan_obj)
}
