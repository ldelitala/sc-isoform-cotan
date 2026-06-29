#!/usr/bin/env Rscript
# setup_env.R
# Initializes the R environment and installs required thesis dependencies.

# Set a default CRAN mirror so the script runs headlessly
options(repos = c(CRAN = "https://cloud.r-project.org/"))

if (!requireNamespace("COTAN", quietly = TRUE)) {
  message("Installing COTAN from GitHub repository...")
  remotes::install_github("seriph78/COTAN")
} else {
  message("COTAN is already installed! Skipping...")
}
