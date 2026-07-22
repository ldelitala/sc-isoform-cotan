# ==============================================================================
# Estimator Stats Logger APIs
# ==============================================================================

#' Log Estimator Statistics
#'
#' Computes distribution summaries (mean, median, sd, min, max) of a numeric vector 
#' and prints them in structured logs.
#'
#' @param estimator_values Numeric vector. Values of the estimator to summarize.
#' @param estimator_name Character. Name of the estimator.
#' @param level Integer. Log level threshold. Default is 1L.
#' @return Invisible TRUE.
#' @export
log_estimator_stats <- function(estimator_values, estimator_name, level = 1L) {
    mean_val <- mean(estimator_values, na.rm = TRUE)
    std_val <- stats::sd(estimator_values, na.rm = TRUE)
    med_val <- stats::median(estimator_values, na.rm = TRUE)
    min_val <- min(estimator_values, na.rm = TRUE)
    max_val <- max(estimator_values, na.rm = TRUE)

    log_info(sprintf("%s distribution:", estimator_name), level = level)
    log_stat(sprintf("avg: %.3f | med: %.3f | sd: %.3f", mean_val, med_val, std_val), level = level)
    log_stat(sprintf("min: %.3f | max: %.3f", min_val, max_val), level = level)
}
