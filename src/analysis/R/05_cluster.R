#!/usr/bin/env Rscript

# Step 05 — cluster the cells on the COTAN object.
#
# The optimisation arguments are the released ones and are kept literal here;
# only the clusterization name, the seed clusterization (guided vs unguided) and
# the core count come from the config.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

cfg <- load_config()
p <- resolve_paths(cfg)

input <- in_file(p, object_path(p, "calculated"))
target <- out_file(p, object_path(p, "clustered"))

clustering <- step_cfg(p, "clustering")
if (is.null(clustering) || is.null(clustering$cl_name)) {
  die("this config has no 'steps: clustering: cl_name' entry")
}
cluster_name <- clustering$cl_name
seed_cluster <- clustering$initial_clusters
cores <- clustering$cores %||% 1L

check_io(
  p,
  reads = c("calculated cotan" = input),
  writes = c("clustered cotan" = target)
)
step_log(p, log_name(p, "cluster"))

log_info(sprintf("Loading cotan object: %s", input))
cotan_obj <- readRDS(input)

initial_clusters <- NULL
if (!is.null(seed_cluster)) {
  log_info(sprintf("Using clusterization '%s' as the starting point...", seed_cluster))
  initial_clusters <- COTAN::getClusters(cotan_obj, clName = seed_cluster)
}

log_stat(sprintf("Clusterization: %s (%s, %d cores)", cluster_name,
                 if (is.null(seed_cluster)) "unguided" else "guided by the given clusters",
                 cores))

cotan_obj <- perform_clustering(
  cotan_obj,
  cl_name = cluster_name,
  gdi_threshold = NaN,
  cores = cores,
  optimize_for_speed = TRUE,
  device_str = "cpu",
  save_obj = TRUE,
  output_dir = dirname(target),
  file_name = basename(target),
  checker = NULL,
  initial_resolution = 0.8,
  max_iterations = 25L,
  use_dea = TRUE,
  distance = NULL,
  use_coex_eigen = FALSE,
  data_method = "",
  genes_sel = "HVG_Seurat",
  num_genes = 2000L,
  num_reduced_comp = 25L,
  hclust_method = "ward.D2",
  initial_clusters = initial_clusters,
  minimum_ut_cluster_size = 50L,
  initial_iteration = 1L,
  clusters = NULL,
  checkers = NULL,
  batch_size = 0L,
  all_check_results = data.frame()
)
