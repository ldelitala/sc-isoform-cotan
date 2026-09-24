#!/usr/bin/env Rscript

# Step 09 — tau (min_dea_contrast) sensitivity sweep.
#
# Reuses the stored COTAN object and cached DEA/p-values, exactly like step 07
# and scripts/verify_dtu_parity.R. For each clusterization listed in
# `steps.dtu.outputs` it re-runs extract_dtu_candidates() over a tau grid and
# records:
#   - DTU events and unique genes (monotone decreasing in tau)
#   - mean |DEA contrast| of the accepted events (rising: higher tau selects
#     stronger, more cluster-specific switches)
#   - events that survive at the strictest threshold (the robust core): the
#     stability signal that makes the threshold choice principled.
# Outputs one CSV + one PNG per clusterization into `paths.plots` (or --out-dir).
# The published tables are never touched. The chosen threshold is the smallest
# tau whose accepted set is >= frac_stable identical to the robust core.
#
# Config keys (steps.sweep_tau):
#   tau_range: [lo, hi]      sweep interval
#   tau_step                 grid resolution
#   frac_stable (0.9)        robust-core agreement needed to call tau stable
#   min_events  (10)         minimum accepted events for a "stable" call
# The published tau anchor and the clusterizations come from `steps.dtu`.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

# Same DEA-readiness rule as step 07: recompute unless a finite DEA is stored.
needs_dea <- function(cotan_obj, cluster_name) {
  all_dea <- COTAN::getClustersCoex(cotan_obj)
  dea_matrix <- all_dea[[cluster_name]]
  if (is.null(dea_matrix)) {
    dea_matrix <- all_dea[[paste0("CL_", cluster_name)]]
  }
  is.null(dea_matrix) || nrow(dea_matrix) == 0L || ncol(dea_matrix) == 0L ||
    !any(is.finite(as.matrix(dea_matrix)))
}

# Order-independent DTU identity, same as the parity harness
dtu_ids <- function(df)
  sort(paste(df$Gene_ID, pmin(df$Transcript_A, df$Transcript_B),
             pmax(df$Transcript_A, df$Transcript_B), sep = "___"))

cfg <- load_config()
p <- resolve_paths(cfg)

dtu <- step_cfg(p, "dtu")
if (is.null(dtu) || length(dtu$outputs) == 0L) {
  die("this config has no 'steps: dtu: outputs' list; the sweep needs its clusterizations")
}
require_paths(p, "plots")

sw <- step_cfg(p, "sweep_tau")
tau_range <- sw$tau_range %||% c(0.01, 0.5)
tau_step <- sw$tau_step %||% 0.02
frac_stable <- sw$frac_stable %||% 0.9
min_events <- sw$min_events %||% 10L
p_value_threshold <- dtu$p_value_threshold %||% 0.05
published_tau <- dtu$min_dea_contrast %||% 1.0

input <- in_file(p, object_path(p, dtu$input_object %||% "calculated"))
cluster_names <- vapply(dtu$outputs, function(output) output$clusterization, character(1L))
targets <- vapply(dtu$outputs, function(output) {
  out_path(p, "plots", paste0("sweep_tau.", output$clusterization, ".csv"))
}, character(1L))

check_io(
  p,
  reads = c("cotan object" = input),
  writes = stats::setNames(targets, basename(targets))
)
step_log(p, log_name(p, "sweep_tau"))

log_info(sprintf("Loading cotan object: %s", input))
cotan_obj <- readRDS(input)

for (i in seq_along(dtu$outputs)) {
  cluster_name <- cluster_names[[i]]
  target <- targets[[i]]

  log_header(sprintf("tau sweep for clusterization '%s'", cluster_name))
  log_stat(sprintf("Grid %.3g..%.3g (step %.3g); published tau=%.3g; p <= %.3g",
                   tau_range[1], tau_range[2], tau_step, published_tau, p_value_threshold))

  if (needs_dea(cotan_obj, cluster_name)) {
    log_info(sprintf("Differential expression missing or empty — running dea_on_clusters('%s')",
                     cluster_name))
    cotan_obj <- dea_on_clusters(cotan_obj, cl_name = cluster_name, clusters = NULL)
  } else {
    log_info(sprintf("Reusing the differential expression stored for '%s'", cluster_name))
  }

  tau_grid <- sort(unique(c(seq(tau_range[1], tau_range[2], by = tau_step),
                            published_tau)))
  tau_ref <- max(tau_grid)  # strict end of the range -> the robust core

  core_df <- extract_dtu_candidates(
    cotan_obj, clusterization_name = cluster_name,
    p_value_threshold = p_value_threshold, min_dea_contrast = tau_ref,
    gene_name_col = dtu$gene_name_col, output_directory = NULL
  )
  core <- dtu_ids(core_df)

  rows <- vector("list", length(tau_grid))
  for (j in seq_along(tau_grid)) {
    tau <- tau_grid[j]
    df <- extract_dtu_candidates(
      cotan_obj, clusterization_name = cluster_name,
      p_value_threshold = p_value_threshold, min_dea_contrast = tau,
      gene_name_col = dtu$gene_name_col, output_directory = NULL
    )
    if (nrow(df) == 0L) {
      rows[[j]] <- data.frame(tau = tau, events = 0L, genes = 0L,
                              mean_contrast = NA, in_core = 0L, frac_in_core = NA)
      next
    }
    ids <- dtu_ids(df)
    in_core <- sum(ids %in% core)
    rows[[j]] <- data.frame(
      tau = tau, events = nrow(df), genes = length(unique(df$Gene_ID)),
      mean_contrast = mean(pmax(df$Max_Contrast_A, df$Max_Contrast_B)),
      in_core = in_core, frac_in_core = in_core / nrow(df)
    )
  }
  res <- do.call(rbind, rows)

  stable <- res[!is.na(res$frac_in_core) & res$frac_in_core >= frac_stable &
                  res$events >= min_events, ]
  chosen <- if (nrow(stable) > 0L) min(stable$tau) else NA
  # float-safe: pick the grid point nearest the published tau (seq() drifts)
  at_pub <- res[which.min(abs(res$tau - published_tau)), ]

  write.csv(res, target, row.names = FALSE)

  png_path <- sub("\\.csv$", ".png", target)
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    plt <- ggplot2::ggplot(res, ggplot2::aes(x = tau)) +
      ggplot2::geom_vline(xintercept = published_tau, linetype = "dashed", colour = "grey40") +
      ggplot2::geom_line(ggplot2::aes(y = events, colour = "DTU events"), linewidth = 1) +
      ggplot2::geom_line(ggplot2::aes(y = in_core, colour = sprintf("robust (survive tau=%.2f)", tau_ref)),
                         linewidth = 1) +
      ggplot2::scale_y_continuous(name = "candidate count") +
      ggplot2::labs(title = sprintf("tau sensitivity: %s / %s", cfg$dataset, cluster_name),
                    x = expression(tau ~ " (min DEA contrast)"),
                    caption = sprintf("dashed: published tau=%.2f (%d events); stable tau (frac>=%.2f, n>=%d): %s",
                                      published_tau, at_pub$events, frac_stable, min_events,
                                      if (is.na(chosen)) "none" else format(chosen, digits = 2))) +
      ggplot2::theme_bw() + ggplot2::theme(legend.position = "bottom")
    ggplot2::ggsave(png_path, plt, width = 11, height = 8, dpi = 300)
  }

  log_stat(sprintf("Grid %g..%g (%d pts); events %d..%d; robust core %d; published tau=%.2f -> %d events",
                   min(tau_grid), max(tau_grid), length(tau_grid),
                   min(res$events), max(res$events), length(core),
                   published_tau, at_pub$events))
  log_stat(sprintf("Stable tau = %s", if (is.na(chosen)) "none" else format(chosen, digits = 2)))
  log_stat(sprintf("Wrote %s (+ png)", basename(target)))
}
