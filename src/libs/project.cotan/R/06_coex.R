# Global cache for p-value matrices to survive S4 copies
.p_values_cache <- new.env(parent = emptyenv())

.get_object_key <- function(cotan_obj) {
    geo <- "unknown"
    tryCatch({
        geo <- COTAN::getMetadataElement(cotan_obj, "GEO")
        if (is.null(geo) || length(geo) == 0 || geo == "") geo <- "unknown"
    }, error = function(e) {})
    
    n_cells <- COTAN::getNumCells(cotan_obj)
    n_genes <- COTAN::getNumGenes(cotan_obj)
    
    cells <- COTAN::getCells(cotan_obj)
    cells_hash <- if (length(cells) > 0) {
        sum(utf8ToInt(cells[1])) + sum(utf8ToInt(cells[length(cells)]))
    } else {
        0
    }
    
    return(paste(geo, n_cells, n_genes, cells_hash, sep = "_"))
}

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
#' @param estimator_logs Boolean. Flag to enable logs from solver estimator. Default is FALSE.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_prepared.rds"`.
#'
#' @return An updated `COTAN` object ready for COEX calculation.
#'
#' @importFrom COTAN estimateLambdaLinear estimateNuLinear estimateDispersionViaSolver getLambda
#' @importFrom COTAN getNu getDispersion estimatorsAreReady setLoggingLevel
#' @import project.logger
#' @import project.utils
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
    log_header("prepare to coex")

    # --- 1. LAMBDA ---
    log_cotan_execution("estimateLambdaLinear()")
    cotan_obj <- estimateLambdaLinear(cotan_obj)
    log_cotan_execution("estimateLambdaLinear()", is_complete = TRUE)

    # --- 2. NU ---
    log_cotan_execution("estimateNuLinear()")
    cotan_obj <- estimateNuLinear(cotan_obj)
    log_cotan_execution("estimateNuLinear()", is_complete = TRUE)

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

    if (!estimatorsAreReady(cotan_obj)) {
        log_error("The estimators (lambda, nu, dispersion) were not calculated correctly or are incomplete.",
            stop_exec = TRUE
        )
    }

    if (!is.null(output_dir)) {
        log_info("Saving COTAN object...")
        save_object(cotan_obj, output_dir, file_name)
    }

    # Logging estimators distribution statistics at the very end
    lambda_values <- getLambda(cotan_obj)
    log_estimator_stats(estimator_values = lambda_values, estimator_name = "Lambda")

    nu_values <- getNu(cotan_obj)
    log_estimator_stats(estimator_values = nu_values, estimator_name = "Nu")

    dispersion_values <- getDispersion(cotan_obj)
    log_estimator_stats(estimator_values = dispersion_values, estimator_name = "Dispersion")

    log_header(is_complete = TRUE)

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
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_coex.rds"`.
#'
#' @return An updated `COTAN` object containing the calculated COEX matrix.
#'
#' @importFrom COTAN calculateCoex estimatorsAreReady isCoexAvailable
#' @importFrom methods is
#' @import project.logger
#' @import project.utils
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
    log_header("calculate coex")

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

    problematic_pairs_fraction <- NULL

    # Handle output structure dynamically
    if (is.list(coex_result) && !methods::is(coex_result, "COTAN")) {
        cotan_obj <- Filter(function(item) methods::is(item, "COTAN"), coex_result)[[1]]

        numeric_values <- Filter(is.numeric, coex_result)
        if (length(numeric_values) > 0) {
            problematic_pairs_fraction <- numeric_values[[1]]

            if (problematic_pairs_fraction > 0.1) {
                log_warn("High fraction of problematic pairs detected. Data might be extremely sparse.")
            }
        }
    } else if (methods::is(coex_result, "COTAN")) {
        cotan_obj <- coex_result
    } else {
        log_error("Unexpected return type from calculateCoex().", stop_exec = TRUE)
    }

    coex_success <- FALSE
    if (COTAN::isCoexAvailable(cotan_obj, actOnCells = act_on_cells)) {
        coex_success <- TRUE
    } else {
        log_error("Status: Calculation finished, but COEX matrix is unavailable.", stop_exec = FALSE)
    }

    if (!is.null(output_dir)) {
        save_object(cotan_obj, output_dir, file_name)
    }

    if (!is.null(problematic_pairs_fraction)) {
        log_stat(sprintf("Problematic Pairs (PPFract): %.4f%%", problematic_pairs_fraction * 100))
    }
    if (coex_success) {
        log_stat("Status: COEX matrix generated and aligned successfully.")
    }

    log_header(is_complete = TRUE)

    return(cotan_obj)
}

#' Calculate and Store p-values for a COTAN Object
#'
#' @param cotan_obj A `COTAN` object.
#' @param stat_type Character. Which statistic to use ("S" or "G"). Default is "S".
#' @param gene_subset_col Character vector. Gene subset for columns. Default is empty.
#' @param gene_subset_row Character vector. Gene subset for rows. Default is empty.
#' @param cores Integer. Number of cores to use. Default is 1L.
#' @param chunk_size Integer. Chunk size for parallel processing. Default is 1024L.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_p_value.rds"`.
#' @return A `COTAN` object with the p-values stored as an attribute.
#' @importFrom COTAN calculatePValue
#' @import project.logger
#' @import project.utils
#' @export
calculate_p_value <- function(
  cotan_obj,
  stat_type = "S",
  gene_subset_col = vector(mode = "character"),
  gene_subset_row = vector(mode = "character"),
  cores = 1L,
  chunk_size = 1024L,
  output_dir = NULL,
  file_name = "cotan_p_value.rds"
) {
    log_header("calculate p value")
    log_cotan_execution("calculatePValue()")

    p_value_matrix <- COTAN::calculatePValue(
        cotan_obj,
        statType = stat_type,
        geneSubsetCol = gene_subset_col,
        geneSubsetRow = gene_subset_row,
        cores = cores,
        chunkSize = chunk_size
    )

    log_cotan_execution("calculatePValue()", is_complete = TRUE)
    
    # Store in global package cache
    key <- .get_object_key(cotan_obj)
    .p_values_cache[[key]] <- p_value_matrix
    
    # Also store in attributes as fallback
    attr(cotan_obj, "p_values") <- p_value_matrix
    attr(cotan_obj@metaDataset, "p_values") <- p_value_matrix
    
    if (!is.null(output_dir)) {
        log_info("Saving COTAN object...")
        save_object(cotan_obj, output_dir, file_name)
    }

    log_header(is_complete = TRUE)
    return(cotan_obj)
}
