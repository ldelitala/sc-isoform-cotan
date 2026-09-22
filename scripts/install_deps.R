#!/usr/bin/env Rscript
# Installs the pinned R dependencies that conda cannot provide.
# Run inside the `cotanisoform-analysis` env:  Rscript scripts/install_deps.R
options(repos = c(CRAN = "https://cloud.r-project.org/"))

cotan_commit <- "be93aa8" # seriph78/COTAN @ v2.13.1 — the commit the results were produced with
cotan_version <- "2.13.1"

if (!requireNamespace("COTAN", quietly = TRUE)) {
  remotes::install_github("seriph78/COTAN", ref = cotan_commit, upgrade = "never")
}
stopifnot(as.character(utils::packageVersion("COTAN")) == cotan_version)
cat("COTAN", cotan_version, "OK\n")
