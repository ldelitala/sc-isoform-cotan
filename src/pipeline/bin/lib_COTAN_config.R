#!/usr/bin/env Rscript

# FILE NAME: lib_COTAN_config.R
# Shared configuration for all COTAN pipeline scripts

suppressPackageStartupMessages({
  library(COTAN)
  library(zeallot)
  library(conflicted)
})

config_cotan_workflow <- function(output_dir, log_file_name) {

  # 1. Resolve Conflicts
  conflict_prefer("%<-%", "zeallot")

  # 2. Enable Parallel Processing
  options(parallelly.fork.enable = TRUE)

  # 3. Standardize Output Directories
  data_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

  # 4. Standardize Logging
  setLoggingLevel(2L)
  setLoggingFile(file.path(data_dir, log_file_name))

  return (data_dir)

}