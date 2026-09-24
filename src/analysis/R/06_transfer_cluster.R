#!/usr/bin/env Rscript

# Step 06 — copy the gene-level cluster labels onto the transcript object.
#
# This is what makes the comparison of step 08 possible: the transcript object
# then carries two clusterizations, its own ("merged", from step 05 of the
# transcript config) and the transferred gene-level one.
#
# NOTE: the injection uses `coexDF = data.frame()`, so the new clusterization has
# NO differential expression yet. Step 07 therefore always has to run
# `dea_on_clusters()` for this clusterization before extracting candidates.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

cfg <- load_config()
p <- resolve_paths(cfg)

transfer <- step_cfg(p, "transfer_cluster")
if (is.null(transfer)) {
  die("this config has no 'steps: transfer_cluster' block")
}

source_path <- in_file(p, object_path(p, transfer$source_object %||% "clustered"))
target_path <- in_file(p, object_path(p, transfer$target_object %||% "clustered"))
output_path <- out_file(p, file.path(dirname(target_path), transfer$file_name))
cluster_name <- transfer$source_cluster %||% die("transfer_cluster: source_cluster is required")

check_io(
  p,
  reads = c("gene-level cotan object" = source_path, "transcript cotan object" = target_path),
  writes = c("transcript object with gene labels" = output_path)
)
step_log(p, log_name(p, "transfer_clusters"))

log_header("Transfer Gene Clusters to Transcripts")

log_info(sprintf("Loading gene-level object: %s", source_path))
cotan_genes <- readRDS(source_path)

log_info(sprintf("Loading transcript object: %s", target_path))
cotan_transcripts <- readRDS(target_path)

log_info(sprintf("Extracting clusterization '%s'...", cluster_name))
clusters_genes <- COTAN::getClusters(cotan_genes, clName = cluster_name)

log_info("Mapping gene clusters to transcript cells...")
cells_transcripts <- COTAN::getCells(cotan_transcripts)
transferred_clusters <- stats::setNames(rep("-1", length(cells_transcripts)), cells_transcripts)
common_cells <- intersect(names(clusters_genes), cells_transcripts)

transferred_clusters[common_cells] <- as.character(clusters_genes[common_cells])
transferred_clusters <- as.factor(transferred_clusters)

log_stat(sprintf("Common cells mapped: %d", length(common_cells)))
log_stat(sprintf("Cells left unassigned (-1): %d", length(cells_transcripts) - length(common_cells)))

log_info("Injecting the gene clusterization into the transcript object...")
cotan_transcripts <- COTAN::addClusterization(
  objCOTAN = cotan_transcripts,
  clName = cluster_name,
  clusters = transferred_clusters,
  coexDF = data.frame(),
  override = TRUE
)

log_info(sprintf("Saving object: %s", output_path))
saveRDS(cotan_transcripts, output_path)

log_header(is_complete = TRUE)
