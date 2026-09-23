#!/usr/bin/env Rscript
#
# tau (min_dea_contrast) sensitivity sweep.
#
# Reuses the stored COTAN objects and cached DEA/p-values, exactly like
# verify_dtu_parity.R. For each tau in the grid it re-runs
# extract_dtu_candidates() and records:
#   - DTU events and unique genes (monotone decreasing in tau)
#   - mean |DEA contrast| of the accepted events (rising: higher tau selects
#     stronger, more cluster-specific switches)
#   - events that survive at the strictest threshold (the robust core): the
#     stability signal that makes the threshold choice principled.
# Outputs one CSV + one plot per case to scratch; published tables are never
# touched. The chosen threshold is the smallest tau whose accepted set is
# >= frac_stable identical to the robust core.
#
# Usage (on athena, from the repository root):
#   Rscript scripts/sweep_tau.R [--root=DIR] [--out=DIR] [--case=NAME]

suppressPackageStartupMessages(library(cotanisoform))
suppressPackageStartupMessages(library(ggplot2))

parse_args <- function(args) {
    opts <- list(root = "/data/lorenzo_delitala", out = NULL, case = NULL,
                 frac_stable = 0.9, min_events = 10)
    for (arg in args) {
        if (!grepl("^--", arg)) stop(sprintf("unexpected argument: %s", arg))
        body <- sub("^--", "", arg)
        key <- sub("=.*$", "", body)
        val <- if (grepl("=", body)) sub("^[^=]+=", "", body) else TRUE
        if (!key %in% names(opts)) stop(sprintf("unknown option: %s", arg))
        opts[[key]] <- val
    }
    opts
}

opts <- parse_args(commandArgs(trailingOnly = TRUE))
root <- normalizePath(opts$root, mustWork = FALSE)
out <- if (is.null(opts$out)) file.path(root, "scratch", "tau_sweep") else normalizePath(opts$out, mustWork = FALSE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
frac_stable <- opts$frac_stable
min_events <- opts$min_events

# Same cases as verify_dtu_parity.R. The two datasets live in different
# contrast regimes, so each gets its own sweep range and resolution, and the
# published tau is forced onto the grid as an anchor.
cases <- list(
    list(name = "arrigoni",
         objects = c("data/project_files/arrigoni/objects/calculated.cotan.rds",
                     "data/project_files/arrigoni/objects/calculated.transcript.cotan.rds"),
         clusterization = "Known_Cell_Types",
         # well-separated cell lines: strong contrasts, sweep the high range
         published_tau = 0.2, tau_range = c(0.02, 0.5), tau_step = 0.02),
    list(name = "ding_merged",
         objects = "data/project_files/ding/cortex_2/objects/clustered.transcript.with_gene_labels.rds",
         clusterization = "merged",
         # continuous differentiation: subtler switches, resolve the low range
         published_tau = 0.05, tau_range = c(0.01, 0.3), tau_step = 0.01),
    list(name = "ding_gene_cluster",
         objects = "data/project_files/ding/cortex_2/objects/clustered.transcript.with_gene_labels.rds",
         clusterization = "local_gene_cluster",
         published_tau = 0.05, tau_range = c(0.01, 0.3), tau_step = 0.01)
)

# Order-independent DTU identity, same as the parity harness
dtu_ids <- function(df)
    sort(paste(df$Gene_ID, pmin(df$Transcript_A, df$Transcript_B),
               pmax(df$Transcript_A, df$Transcript_B), sep = "___"))

selected <- if (is.null(opts$case)) cases else Filter(function(c) c$name == opts$case, cases)
if (length(selected) == 0L) stop("no case selected")

for (case in selected) {
    object_path <- case$objects[file.exists(case$objects)][1]
    if (is.na(object_path)) { cat(sprintf("[%s] SKIP: no object found\n", case$name)); next }
    # Per-case grid, with the published tau guaranteed present
    tau_grid <- sort(unique(c(seq(case$tau_range[1], case$tau_range[2], by = case$tau_step),
                              case$published_tau)))
    tau_ref <- max(tau_grid)   # strict end of this case's range -> the robust core

    cat(sprintf("[%s] reading %s\n", case$name, object_path))
    cotan_obj <- readRDS(object_path)

    if (is.null(attr(cotan_obj, "p_values")) && is.null(attr(cotan_obj@metaDataset, "p_values")))
        cotan_obj <- calculate_p_value(cotan_obj, cores = 1L, chunk_size = 512L)
    dea <- COTAN::getClustersCoex(cotan_obj)
    dea_mat <- dea[[case$clusterization]]
    if (is.null(dea_mat)) dea_mat <- dea[[paste0("CL_", case$clusterization)]]
    if (is.null(dea_mat) || nrow(dea_mat) == 0L || ncol(dea_mat) == 0L ||
        !any(is.finite(as.matrix(dea_mat))))
        cotan_obj <- dea_on_clusters(cotan_obj, cl_name = case$clusterization, clusters = NULL)

    # Robust core at the strictest threshold
    core_df <- extract_dtu_candidates(cotan_obj, clusterization_name = case$clusterization,
                                      p_value_threshold = 0.05, min_dea_contrast = tau_ref,
                                      gene_name_col = "gene_name", output_directory = NULL)
    core <- dtu_ids(core_df)

    rows <- vector("list", length(tau_grid))
    for (i in seq_along(tau_grid)) {
        tau <- tau_grid[i]
        df <- extract_dtu_candidates(cotan_obj, clusterization_name = case$clusterization,
                                     p_value_threshold = 0.05, min_dea_contrast = tau,
                                     gene_name_col = "gene_name", output_directory = NULL)
        if (nrow(df) == 0L) {
            rows[[i]] <- data.frame(tau = tau, events = 0L, genes = 0L, mean_contrast = NA,
                                    in_core = 0L, frac_in_core = NA)
            next
        }
        ids <- dtu_ids(df)
        in_core <- sum(ids %in% core)
        rows[[i]] <- data.frame(tau = tau, events = nrow(df), genes = length(unique(df$Gene_ID)),
                                mean_contrast = mean(pmax(df$Max_Contrast_A, df$Max_Contrast_B)),
                                in_core = in_core, frac_in_core = in_core / nrow(df))
    }
    res <- do.call(rbind, rows)

    # smallest tau whose accepted set is >= frac_stable identical to the robust
    # core, guarded by a minimum count so tiny tails cannot trivially "pass"
    stable <- res[!is.na(res$frac_in_core) & res$frac_in_core >= frac_stable & res$events >= min_events, ]
    chosen <- if (nrow(stable) > 0L) min(stable$tau) else NA
    at_pub <- res[res$tau == case$published_tau, ]

    write.csv(res, file.path(out, paste0(case$name, "_tau_sweep.csv")), row.names = FALSE)

    p <- ggplot(res, aes(x = tau)) +
        geom_vline(xintercept = case$published_tau, linetype = "dashed", colour = "grey40") +
        geom_line(aes(y = events, colour = "DTU events"), linewidth = 1) +
        geom_line(aes(y = in_core, colour = sprintf("robust (survive tau=%.2f)", tau_ref)), linewidth = 1) +
        scale_y_continuous(name = "candidate count") +
        labs(title = sprintf("tau sensitivity: %s", case$name),
             x = expression(tau ~ " (min DEA contrast)"),
             caption = sprintf("dashed: published tau=%.2f (%d events);  stable tau (frac>=%.2f, n>=%d): %s",
                               case$published_tau, at_pub$events, frac_stable, min_events,
                               if (is.na(chosen)) "none" else format(chosen, digits = 2))) +
        theme_bw() + theme(legend.position = "bottom")
    suppressMessages(ggplot2::ggsave(file.path(out, paste0(case$name, "_tau_sweep.png")),
                                     p, width = 11, height = 8, dpi = 300))

    cat(sprintf("[%s] grid %g..%g (%d pts); events %d..%d; robust core %d; published tau=%.2f -> %d events\n",
                case$name, min(tau_grid), max(tau_grid), length(tau_grid),
                min(res$events), max(res$events), length(core),
                case$published_tau, at_pub$events))
    cat(sprintf("[%s] stable tau = %s\n", case$name,
                if (is.na(chosen)) "none" else format(chosen, digits = 2)))
}
