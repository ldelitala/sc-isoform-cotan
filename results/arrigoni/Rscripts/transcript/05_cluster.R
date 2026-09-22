library(project.logger)
library(project.cotan)
library(COTAN)

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/logs", 
  file_name = "cluster.transcript.log"
)

log_info("Loading Cotan object with coex, p-value and gdi...")
cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/arrigoni/objects/calculated.transcript.cotan.rds")

log_info("Getting Known Clusters...")
known_clusters <- getClusters(cotan_obj, clName = "Known_Cell_Types")

log_info("Starting guided clustering using Known_Cell_Types as initial_clusters...")
cotan_obj <- perform_clustering(
  cotan_obj,
  cl_name = "local_transcript_cluster",
  gdi_threshold = NaN,
  cores = 1L,
  optimize_for_speed = TRUE,
  device_str = "cpu",
  save_obj = TRUE,
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/objects",
  file_name = "clustered.transcript.rds",
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
  initial_clusters = known_clusters,
  minimum_ut_cluster_size = 50L,
  initial_iteration = 1L,
  clusters = NULL,
  checkers = NULL,
  batch_size = 0L,
  all_check_results = data.frame()
)

