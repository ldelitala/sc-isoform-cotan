#!/usr/bin/env Rscript

# Runs the steps listed in `run:` of a config, in order, one separate R process
# each, stopping at the first failure.
#
# Usage (from the repository root):
#   Rscript analysis/run_all.R --config analysis/config/arrigoni.yaml
#   Rscript analysis/run_all.R --config analysis/config/ding_cortex_2.transcript.yaml --from 07 --to 08
#   Rscript analysis/run_all.R --config analysis/config/arrigoni.yaml --dry-run
#
# --root, --out-dir and --dry-run are forwarded to every step.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "lib", "common.R"))

cfg <- load_config(option_list = list(
  make_option(
    "--from",
    type = "character", default = NULL, metavar = "NN",
    help = "First step to run (inclusive), e.g. --from 07"
  ),
  make_option(
    "--to",
    type = "character", default = NULL, metavar = "NN",
    help = "Last step to run (inclusive), e.g. --to 08"
  )
))

step_numbers <- as.character(unlist(cfg$run))
if (length(step_numbers) == 0L) {
  die("config has no 'run:' list; add one with the steps to execute, e.g. [\"00\", \"01\", \"02\"]")
}

from <- as.integer(cfg$cli$from %||% step_numbers[[1]])
to <- as.integer(cfg$cli$to %||% step_numbers[[length(step_numbers)]])
selected <- step_numbers[as.integer(step_numbers) >= from & as.integer(step_numbers) <= to]

if (length(selected) == 0L) {
  die(sprintf("no step of 'run: [%s]' falls in the range %d-%d",
              paste(step_numbers, collapse = ", "), from, to))
}

rscript <- file.path(R.home("bin"), "Rscript")
step_dir <- file.path(script_dir, "R")
forward <- character()
if (!is.null(cfg$cli$root)) {
  forward <- c(forward, "--root", cfg$cli$root)
}
if (!is.null(cfg$out_dir)) {
  forward <- c(forward, "--out-dir", cfg$out_dir)
}
if (isTRUE(cfg$dry_run)) {
  forward <- c(forward, "--dry-run")
}

cat(sprintf(
  "== %s (%s), steps %s ==\n",
  cfg$dataset, cfg$level %||% "?", paste(selected, collapse = " -> ")
))

for (number in selected) {
  script <- list.files(step_dir, pattern = sprintf("^%s_", number), full.names = TRUE)
  if (length(script) != 1L) {
    die(sprintf("found %d scripts matching step '%s' in %s", length(script), number, step_dir))
  }

  args <- c(script, "--config", normalizePath(cfg$cli$config), forward)
  cat(sprintf("\n==> step %s: Rscript %s\n", number, paste(args, collapse = " ")))

  status <- system2(rscript, args = args)
  if (!identical(as.integer(status), 0L)) {
    die(sprintf("step %s failed with exit status %s", number, status))
  }
}

cat(sprintf("\n== %d step(s) completed ==\n", length(selected)))
