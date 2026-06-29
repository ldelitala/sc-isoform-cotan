#!/usr/bin/env Rscript
# setup_env.R
# Initializes the R environment and installs required thesis dependencies.

# 1. Install 'remotes' (A lightweight tool to install packages from GitHub)
if (!requireNamespace("remotes", quietly = TRUE)) {
  message("Installing 'remotes' package...")
  install.packages("remotes")
}

# 2. Install COTAN from GitHub
# We check if it exists first so the script is "idempotent"
if (!requireNamespace("COTAN", quietly = TRUE)) {
  message("Installing COTAN from GitHub repository...")

  # Install the specific devel branch or main branch you are using
  remotes::install_github("seriph78/COTAN")
} else {
  message("COTAN is already installed! Skipping...")
}

message("Environment setup complete. You are ready to run the pipeline.")
