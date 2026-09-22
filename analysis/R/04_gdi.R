#!/usr/bin/env Rscript

# Step 04 — GDI plot for a panel of marker genes (or transcripts), one line per
# group. Marker panels live in the config because they are dataset-specific.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

suppressPackageStartupMessages(library(ggplot2))

cfg <- load_config()
p <- resolve_paths(cfg)

gdi <- step_cfg(p, "gdi")
if (is.null(gdi)) {
  die("this config has no 'steps: gdi' block")
}

input <- in_file(p, object_path(p, "calculated"))
target <- out_path(p, "plots", gdi$file_name)

check_io(
  p,
  reads = c("calculated cotan" = input),
  writes = c("gdi plot" = target)
)
step_log(p, log_name(p, "plot_gdi"))

log_info(sprintf("Loading cotan object: %s", input))
cotan_obj <- readRDS(input)

log_info("Looking for the panel features in the object metadata...")
if (identical(cfg$level, "gene")) {
  group_markers <- gdi$markers
} else {
  genes_info <- COTAN::getMetadataGenes(cotan_obj)
  genes_info$feature <- rownames(genes_info)
  group_markers <- lapply(gdi$markers, function(panel) {
    genes_info$feature[genes_info$gene_name %in% panel]
  })
}

for (group_name in names(group_markers)) {
  log_stat(sprintf("%s: %d feature(s)", group_name, length(group_markers[[group_name]])))
}

threshold <- gdi$threshold
log_cotan_execution("GDIPlot()", condition = gdi$condition, GDIThreshold = threshold %||% "default")
plot_args <- list(objCOTAN = cotan_obj, genes = group_markers, condition = gdi$condition)
if (!is.null(threshold)) {
  plot_args$GDIThreshold <- threshold
}
gdi_plot <- do.call(COTAN::GDIPlot, plot_args)
log_cotan_execution(is_complete = TRUE)

log_info(sprintf("Saving GDI plot: %s", target))
ggplot2::ggsave(filename = target, plot = gdi_plot, width = 11, height = 8, dpi = 300)
