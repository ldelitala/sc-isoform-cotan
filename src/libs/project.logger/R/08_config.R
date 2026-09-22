# ==============================================================================
# Workflow Configuration APIs
# ==============================================================================

#' Generate a unique log file path to prevent overwriting
#'
#' @param dir_path Character. The directory path where the log will be stored.
#' @param base_filename Character. The target log file name.
#'
#' @return Character. A unique path for the log file.
#' @keywords internal
#' @noRd
.generate_unique_log_path <- function(dir_path, base_filename) {
  base_name <- tools::file_path_sans_ext(base_filename)
  ext <- tools::file_ext(base_filename)
  if (ext != "") ext <- paste0(".", ext)
  
  log_path <- file.path(dir_path, base_filename)
  counter <- 1
  
  while (file.exists(log_path)) {
    new_log_name <- sprintf("%s_%d%s", base_name, counter, ext)
    log_path <- file.path(dir_path, new_log_name)
    counter <- counter + 1
  }
  
  return(log_path)
}

#' Configure the COTAN workflow with Log Rotation
#'
#' @param output_dir Character. Directory where logs and outputs will be saved. Default is ".".
#' @param file_name Character. Name of the log file. Default is "cotan_pipeline.log".
#' @param parallel Boolean. Enable parallel processing. Default is TRUE.
#' @param logging_level Integer. Logging verbosity level (0-/data/lorenzo_delitala/src/libs/project.logger3). Default is 2L.
#'
#' @return The normalized path to the output directory.
#'
#' @export
config_workflow <- function(
  output_dir = ".",
  file_name = "cotan_pipeline.log",
  parallel = TRUE,
  logging_level = 2L
) {
  reset_log_state()

  options(error = function() {
    reset_log_state()
    cat("\n") # Spazio pulito prima della traccia dell'errore
    traceback()
  })

  COTAN::setLoggingLevel(logging_level)

  log_header("Configuring Workflow")

  log_info("Preparing file path...")

  data_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

  log_path <- .generate_unique_log_path(data_dir, file_name)

  log_cotan_execution("setLoggingFile()", logFileName = log_path)
  COTAN::setLoggingFile(log_path)
  log_cotan_execution("setLoggingFile()", is_complete = TRUE)

  log_info("Setting up conflict resolution (zeallot)...")
  suppressMessages(conflicted::conflict_prefer("%<-%", "zeallot"))

  log_info("Setting up parallel processing...")
  options(parallelly.fork.enable = parallel)

  log_stat(sprintf("Logging level set to: %d", logging_level))
  log_stat(sprintf("Logging path set to: %s", log_path))

  log_header("Configuring Workflow", is_complete = TRUE)

  return(data_dir)
}