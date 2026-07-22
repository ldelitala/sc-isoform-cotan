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
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_prepared.rds"`.
#'
#' @return An updated `COTAN` object ready for COEX calculation.
#'
#' @importFrom COTAN estimateLambdaLinear estimateNuLinear estimateDispersionViaSolver getLambda
#' @importFrom COTAN getNu getDispersion estimatorsAreReady setLoggingLevel
#' @export
prepare_to_coex <- function(
  cotan_obj,
  threshold = 0.01,
  cores = 1L,
  max_iterations = 100L,
  chunk_size = 1024L,
  estimator_logs = FALSE,
  output_dir = NULL,
  file_name = "cotan_prepared.rds"
) {
    log_header("Preparing COTAN Object")

    # --- 1. LAMBDA ---
    log_cotan_execution("estimateLambdaLinear()")
    cotan_obj <- estimateLambdaLinear(cotan_obj)
    log_cotan_execution("estimateLambdaLinear()", is_complete = TRUE)

    lambda_values <- getLambda(cotan_obj)
    log_estimator_stats(estimator_values = lambda_values, estimator_name = "Lambda")

    # --- 2. NU ---
    log_cotan_execution("estimateNuLinear()")
    cotan_obj <- estimateNuLinear(cotan_obj)
    log_cotan_execution("estimateNuLinear()", is_complete = TRUE)

    nu_values <- getNu(cotan_obj)
    log_estimator_stats(estimator_values = nu_values, estimator_name = "Nu")

    # --- 3. DISPERSION ---
    log_cotan_execution("estimateDispersionViaSolver()", threshold = threshold, cores = cores, maxIterations = max_iterations, chunkSize = chunk_size)

    if (!estimator_logs) {
        old_log_level <- getOption("COTAN.LogLevel", default = 1L)
        setLoggingLevel(0L)
    }

    tryCatch({
        cotan_obj <- estimateDispersionViaSolver(
            cotan_obj,
            threshold = threshold,
            cores = cores,
            maxIterations = max_iterations,
            chunkSize = chunk_size
        )
    }, finally = {
        if (!estimator_logs) {
            setLoggingLevel(old_log_level)
        }
    })
    log_cotan_execution("estimateDispersionViaSolver()", is_complete = TRUE)

    dispersion_values <- getDispersion(cotan_obj)
    log_estimator_stats(estimator_values = dispersion_values, estimator_name = "Dispersion")

    if (!estimatorsAreReady(cotan_obj)) {
        log_error("The estimators (lambda, nu, dispersion) were not calculated correctly or are incomplete.",
            stop_exec = TRUE
        )
    }

    if (!is.null(output_dir)) {
        log_info("Saving COTAN object...")
        save_object(cotan_obj, output_dir, file_name)
    }

    log_header("Preparing COEX Complete", is_complete = TRUE)

    return(cotan_obj)
}
