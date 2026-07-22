# COTAN Configuration Module

#' Configure the COTAN workflow with Log Rotation
#'
#' @param output_dir Character. Directory where logs and outputs will be saved.
#' @param log_file_name Character. Name of the log file.
#' @param parallel Boolean. Enable parallel processing.
#' @param logging_level Integer. Logging verbosity level (0-3).
#'
#' @return The normalized path to the output directory.
#'
#' @importFrom tools file_path_sans_ext file_ext
#' @importFrom COTAN setLoggingLevel setLoggingFile
#' @importFrom conflicted conflict_prefer
#' @export
config_workflow <- function(
  output_dir = ".",
  log_file_name = "cotan_pipeline.log",
  parallel = TRUE,
  logging_level = 2L
) {
  reset_log_state()

  options(error = function() {
    reset_log_state()
    cat("\n") # Spazio pulito prima della traccia dell'errore
    traceback()
  })

  setLoggingLevel(logging_level)

  log_header("Configuring Workflow")

  log_info("Preparing file path...")

  data_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

  base_name <- file_path_sans_ext(log_file_name)
  ext <- file_ext(log_file_name)
  if (ext != "") ext <- paste0(".", ext)

  log_path <- file.path(data_dir, log_file_name)
  counter <- 1

  while (file.exists(log_path)) {
    new_log_name <- sprintf("%s_%d%s", base_name, counter, ext)
    log_path <- file.path(data_dir, new_log_name)
    counter <- counter + 1
  }

  log_cotan_execution("setLoggingFile()", logFileName = log_path)
  setLoggingFile(log_path)
  log_cotan_execution("setLoggingFile()", is_complete = TRUE)

  log_info("Setting up conflict resolution (zeallot)...")
  suppressMessages(conflict_prefer("%<-%", "zeallot"))

  log_info("Setting up parallel processing...")
  options(parallelly.fork.enable = parallel)

  log_stat(sprintf("Logging level set to: %d", logging_level))
  log_stat(sprintf("Logging path set to: %s", log_path))

  log_header("Configuring Workflow", is_complete = TRUE)

  return(data_dir)
}