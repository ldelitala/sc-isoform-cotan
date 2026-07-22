#' Calculate COEX for a COTAN Object
#'
#' @description
#' Calculates the genes' co-expression (COEX) matrix for a prepared COTAN object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param act_on_cells Boolean. Act on cells. Default is FALSE.
#' @param return_pp_fract Boolean. Return PP fraction. Default is FALSE.
#' @param optimize_for_speed Boolean. Try using the torch library to run matrix calculations. Default is TRUE.
#' @param device_str Character string. Device to use for calculations ("cpu", "cuda"). Default is "cuda".
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_coex.rds"`.
#'
#' @return An updated `COTAN` object containing the calculated COEX matrix.
#'
#' @importFrom COTAN calculateCoex estimatorsAreReady isCoexAvailable
#' @importFrom methods is
#' @export
calculate_coex <- function(
  cotan_obj,
  act_on_cells = FALSE,
  return_pp_fract = FALSE,
  optimize_for_speed = TRUE,
  device_str = "cuda",
  output_dir = NULL,
  file_name = "cotan_coex.rds"
) {
    log_header("Calculating COEX")

    if (!COTAN::estimatorsAreReady(cotan_obj)) {
        log_error("Estimators missing (lambda, nu, dispersion). Cannot calculate COEX.", stop_exec = TRUE)
    }

    if (COTAN::isCoexAvailable(cotan_obj, actOnCells = act_on_cells)) {
        log_warn("COEX matrix already calculated and aligned. It will be overwritten.")
    }

    log_cotan_execution("calculateCoex()", 
        actOnCells = act_on_cells, returnPPFract = return_pp_fract, optimizeForSpeed = optimize_for_speed,
        deviceStr = device_str
    )

    coex_result <- COTAN::calculateCoex(
        cotan_obj,
        actOnCells = act_on_cells,
        returnPPFract = return_pp_fract,
        optimizeForSpeed = optimize_for_speed,
        deviceStr = device_str
    )
    log_cotan_execution("calculateCoex()", is_complete = TRUE)

    log_info("Verifying integrity and extracting metrics...")

    # Handle output structure dynamically
    if (is.list(coex_result) && !methods::is(coex_result, "COTAN")) {
        cotan_obj <- Filter(function(item) methods::is(item, "COTAN"), coex_result)[[1]]

        numeric_values <- Filter(is.numeric, coex_result)
        if (length(numeric_values) > 0) {
            problematic_pairs_fraction <- numeric_values[[1]]
            log_stat(sprintf("Problematic Pairs (PPFract): %.4f%%", problematic_pairs_fraction * 100))

            if (problematic_pairs_fraction > 0.1) {
                log_warn("High fraction of problematic pairs detected. Data might be extremely sparse.")
            }
        }
    } else if (methods::is(coex_result, "COTAN")) {
        cotan_obj <- coex_result
    } else {
        log_error("Unexpected return type from calculateCoex().", stop_exec = TRUE)
    }

    if (COTAN::isCoexAvailable(cotan_obj, actOnCells = act_on_cells)) {
        log_stat("Status: COEX matrix generated and aligned successfully.")
    } else {
        log_error("Status: Calculation finished, but COEX matrix is unavailable.", stop_exec = FALSE)
    }

    if (!is.null(output_dir)) {
        save_object(cotan_obj, output_dir, file_name)
    }

    log_header("Calculating COEX Complete", is_complete = TRUE)

    return(cotan_obj)
}
