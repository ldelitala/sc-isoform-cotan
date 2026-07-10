#' Prepare COTAN Object for COEX Calculation
#'
#' @description
#' Estimates parameters (lambda, nu, dispersion) needed for COEX calculation.
#'
#' @param cotan_obj A `COTAN` object.
#' @param threshold Numeric. Threshold for convergence in the solver. Default is `0.01`.
#' @param cores Integer. Number of cores to use for parallel execution. Default is `1L`.
#' @param max_iterations Integer. Maximum number of iterations for the solver. Default is `100L`.
#' @param chunk_size Integer. Size of chunks for parallel processing. Default is `1024L`.
#'
#' @return An updated `COTAN` object ready for COEX calculation.
#'
#' @importFrom COTAN estimateLambdaLinear estimateNuLinear estimateDispersionViaSolver getLambda
#' @importFrom COTAN getNu getDispersion estimatorsAreReady setLoggingLevel
#' @importFrom stats median sd
#' @export
prepare_to_coex <- function(
  cotan_obj,
  threshold = 0.01,
  cores = 1L,
  max_iterations = 100L,
  chunk_size = 1024L
) {
    log_header("Preparing COTAN Object")

    log_cotan_execution("estimateLambdaLinear()")
    cotan_obj <- estimateLambdaLinear(cotan_obj)
    log_cotan_execution("estimateLambdaLinear()", is_complete = TRUE)

    lambda_values <- getLambda(cotan_obj)
    log_stat(sprintf("Mean Lambda: %f", mean(lambda_values)))
    log_stat(sprintf("Std Dev Lambda: %f", sd(lambda_values)))
    log_stat(sprintf("Median Lambda: %f", median(lambda_values)))
    log_stat(sprintf("Min Lambda: %f", min(lambda_values)))
    log_stat(sprintf("Max Lambda: %f", max(lambda_values)))

    log_cotan_execution("estimateNuLinear()")
    cotan_obj <- estimateNuLinear(cotan_obj)
    log_cotan_execution("estimateNuLinear()", is_complete = TRUE)

    nu_values <- getNu(cotan_obj)
    log_stat(sprintf("Mean Nu: %f", mean(nu_values)))
    log_stat(sprintf("Std Dev Nu: %f", sd(nu_values)))
    log_stat(sprintf("Median Nu: %f", median(nu_values)))
    log_stat(sprintf("Min Nu: %f", min(nu_values)))
    log_stat(sprintf("Max Nu: %f", max(nu_values)))


    log_stat(sprintf("Threshold: %f", threshold))
    log_stat(sprintf("Cores: %d", cores))
    log_stat(sprintf("Maximum Iterations: %d", max_iterations))
    log_stat(sprintf("Chunk Size: %d", chunk_size))

    log_cotan_execution("estimateDispersionViaSolver()")
    setLoggingLevel(2L)
    cotan_obj <- estimateDispersionViaSolver(
        cotan_obj,
        threshold = threshold,
        cores = cores,
        maxIterations = max_iterations,
        chunkSize = chunk_size
    )
    setLoggingLevel(3L)
    log_cotan_execution("estimateDispersionViaSolver()", is_complete = TRUE)

    dispersion_values <- getDispersion(cotan_obj)
    log_stat(sprintf("Mean Dispersion: %f", mean(dispersion_values, na.rm = TRUE)))
    log_stat(sprintf("Std Dev Dispersion: %f", sd(dispersion_values, na.rm = TRUE)))
    log_stat(sprintf("Median Dispersion: %f", median(dispersion_values, na.rm = TRUE)))
    log_stat(sprintf("Min Dispersion: %f", min(dispersion_values, na.rm = TRUE)))
    log_stat(sprintf("Max Dispersion: %f", max(dispersion_values, na.rm = TRUE)))

    if (!estimatorsAreReady(cotan_obj)) {
        log_error("The estimators (lambda, nu, dispersion) were not calculated correctly or are incomplete.",
            stop_exec = TRUE
        )
    }

    log_header("Preparing COEX Complete", is_complete = TRUE)

    return(cotan_obj)
}

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
#'
#' @return An updated `COTAN` object containing the calculated COEX matrix.
#'
#' @importFrom COTAN calculateCoex estimatorsAreReady isCoexAvailable getNumGenes getNumCells
#' @importFrom methods is
#' @export
calculate_coex <- function(
  cotan_obj,
  act_on_cells = FALSE,
  return_pp_fract = FALSE,
  optimize_for_speed = TRUE,
  device_str = "cuda"
) {
    log_header("Calculating COEX")

    if (!COTAN::estimatorsAreReady(cotan_obj)) {
        log_error("Estimators missing (lambda, nu, dispersion). Cannot calculate COEX.", stop_exec = TRUE)
    }

    if (COTAN::isCoexAvailable(cotan_obj, actOnCells = act_on_cells)) {
        log_warn("COEX matrix already calculated and aligned. It will be overwritten.")
    }

    log_stat(sprintf("Act on Cells: %s", act_on_cells))
    log_stat(sprintf("Return PP Fract: %s", return_pp_fract))
    log_stat(sprintf("Optimize for Speed: %s", optimize_for_speed))
    log_stat(sprintf("Device: %s", device_str))

    log_cotan_execution("calculateCoex()")
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
        cotan_obj <- Filter(function(x) methods::is(x, "COTAN"), coex_result)[[1]]

        nums <- Filter(is.numeric, coex_result)
        if (length(nums) > 0) {
            pp_fract_val <- nums[[1]]
            log_stat(sprintf("Problematic Pairs Fraction (PPFract): %.4f%%", pp_fract_val * 100))

            if (pp_fract_val > 0.1) {
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

    log_header("Calculating COEX", is_complete = TRUE)

    return(cotan_obj)
}

#' Calculate and Store GDI for a COTAN Object
#'
#' @description
#' Computes the Global Differential Expression Index (GDI), stores it, and saves the object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param out_dir Character string. Directory path where the final object will be saved. Default is `"."`.
#' @param cores Integer. Number of cores to use for parallel execution. Default is `1L`.
#' @param stat_type Character string. The type of statistic to use for GDI calculation ("S" or "G"). Default is "S".
#' @param rows_fraction Numeric. Fraction of rows to use for chunking in GDI. Default is 0.05.
#' @param chunk_size Integer. Size of the data chunks for GDI calculation. Default is 1024L.
#'
#' @return An updated `COTAN` object containing the calculated GDI metrics.
#'
#' @importFrom COTAN calculateGDI storeGDI
#' @export
calculate_and_store_gdi <- function(
  cotan_obj,
  out_dir = ".",
  cores = 1L,
  stat_type = "S",
  rows_fraction = 0.05,
  chunk_size = 1024L
) {
    log_header("Computing Global Differential Expression Index (GDI)")

    log_info("GDI calculation parameters:")
    log_stat(sprintf("Output Directory: %s", out_dir))
    log_stat(sprintf("Cores: %d", cores))
    log_stat(sprintf("Statistic Type: %s", stat_type))
    log_stat(sprintf("Rows Fraction: %f", rows_fraction))
    log_stat(sprintf("Chunk Size: %d\n", chunk_size))

    log_cotan_execution("calculateGDI & storeGDI")
    cotan_obj <- storeGDI(
        cotan_obj,
        genesGDI = calculateGDI(
            cotan_obj,
            statType = stat_type,
            rowsFraction = rows_fraction,
            cores = cores,
            chunkSize = chunk_size
        )
    )
    log_cotan_execution("calculateGDI & storeGDI", is_complete = TRUE)

    log_info("Saving the updated COTAN object...")

    if (!dir.exists(out_dir)) {
        log_stat(sprintf("Output directory '%s' does not exist. Creating it...", out_dir))
        dir.create(out_dir, recursive = TRUE)
    }

    out_file <- file.path(out_dir, "cotan_coex_gdi.rds")
    saveRDS(cotan_obj, file = out_file)

    log_stat(sprintf("Successfully saved to: %s", out_file))
    log_header("Calculation Complete", is_complete = TRUE)

    return(cotan_obj)
}
