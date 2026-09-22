library(project.logger)
library(project.cotan)

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", 
  file_name = "cluster.gene.log"
)

log_info("Loading Cotan object with coex, p-value and gdi...")
cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/calculated.gene.cotan.rds")

cotan_obj <- perform_clustering(
  cotan_obj,
  cl_name = "local_gene_cluster",
  gdi_threshold = NaN,
  cores = 40L,
  optimize_for_speed = TRUE,
  device_str = "cpu",
  save_obj = TRUE,
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/plots",
  file_name = "clustered.gene.rds",
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
  initial_clusters = NULL,
  minimum_ut_cluster_size = 50L,
  initial_iteration = 1L,
  clusters = NULL,
  checkers = NULL,
  batch_size = 0L,
  all_check_results = data.frame()
)

