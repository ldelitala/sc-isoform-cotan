#!/usr/bin/env Rscript

# Step 07 — the DTU extraction: one CSV per clusterization listed in
# `steps.dtu.outputs`.
#
# The released runs logged this step as `cotan_calc.<level>.log` (copy-paste from
# the calc step); here it is `dtu.<level>.log`.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

#' Does this clusterization need its differential expression (re)computed?
#'
#' A clusterization can exist with an empty DEA frame — that is how step 06
#' injects transferred labels — and then `extract_dtu_candidates()` finds no
#' contrasts at all. Policies: `auto` (recompute unless a finite DEA is stored),
#' `always`, `never`.
needs_dea <- function(cotan_obj, cluster_name, policy) {
  if (identical(policy, "always")) {
    return(TRUE)
  }
  if (identical(policy, "never")) {
    return(FALSE)
  }

  all_dea <- COTAN::getClustersCoex(cotan_obj)
  dea_matrix <- all_dea[[cluster_name]]
  if (is.null(dea_matrix)) {
    dea_matrix <- all_dea[[paste0("CL_", cluster_name)]]
  }

  is.null(dea_matrix) || nrow(dea_matrix) == 0L || ncol(dea_matrix) == 0L ||
    !any(is.finite(as.matrix(dea_matrix)))
}

cfg <- load_config()
p <- resolve_paths(cfg)

dtu <- step_cfg(p, "dtu")
if (is.null(dtu) || length(dtu$outputs) == 0L) {
  die("this config has no 'steps: dtu: outputs' list")
}
require_paths(p, "workdir")

input <- in_file(p, object_path(p, dtu$input_object %||% "calculated"))
file_names <- vapply(dtu$outputs, function(output) output$file_name, character(1L))
targets <- vapply(dtu$outputs, function(output) {
  out_path(p, "workdir", output$file_name)
}, character(1L))

check_io(
  p,
  reads = c("cotan object" = input),
  writes = stats::setNames(targets, file_names)
)
step_log(p, log_name(p, "dtu"))

policy <- dtu$recompute_dea %||% "auto"
p_value_threshold <- dtu$p_value_threshold %||% 0.05
min_dea_contrast <- dtu$min_dea_contrast %||% 1.0
gene_name_col <- dtu$gene_name_col

log_info(sprintf("Loading cotan object: %s", input))
cotan_obj <- readRDS(input)

for (i in seq_along(dtu$outputs)) {
  cluster_name <- dtu$outputs[[i]]$clusterization

  log_header(sprintf("DTU candidates for clusterization '%s'", cluster_name))
  log_stat(sprintf("Thresholds: p <= %.3g, |DEA contrast| >= %.3g, COEX <= 0",
                   p_value_threshold, min_dea_contrast))

  if (needs_dea(cotan_obj, cluster_name, policy)) {
    log_info(sprintf("Differential expression missing or empty — running dea_on_clusters('%s')",
                     cluster_name))
    cotan_obj <- dea_on_clusters(cotan_obj, cl_name = cluster_name, clusters = NULL)
  } else {
    log_info(sprintf("Reusing the differential expression stored for '%s'", cluster_name))
  }

  # NOTE: extract_dtu_candidates() returns the candidate table, not the COTAN
  # object, so the loop must not assign it over `cotan_obj`.
  dtu_candidates <- extract_dtu_candidates(
    cotan_obj,
    clusterization_name = cluster_name,
    p_value_threshold = p_value_threshold,
    min_dea_contrast = min_dea_contrast,
    gene_name_col = gene_name_col,
    output_directory = dirname(targets[[i]]),
    file_name = basename(targets[[i]])
  )
  log_stat(sprintf("Candidates written: %s", basename(targets[[i]])))
}
