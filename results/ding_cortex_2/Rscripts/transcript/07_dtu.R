library(project.logger)
library(project.cotan)

cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/clustered.transcript.with_gene_labels.rds")

config_workflow(logging_level = 3L, output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", file_name = "cotan_calc.log")


cotan_obj <- dea_on_clusters (cotan_obj, cl_name = "merged", clusters = NULL)

obj <- extract_dtu_candidates(
  cotan_obj,
  clusterization_name = "merged",
  p_value_threshold = 0.05,
  min_dea_contrast = 0.05,
  gene_name_col = "gene_name",
  output_directory = "/data/lorenzo_delitala/data/project_files/ding/cortex_2",
  file_name = "dtu_candidates.transcript_cluster.csv"
)
cotan_obj <- dea_on_clusters (cotan_obj, cl_name = "local_gene_cluster", clusters = NULL)

obj <- extract_dtu_candidates(
  cotan_obj,
  clusterization_name = "local_gene_cluster",
  p_value_threshold = 0.05,
  min_dea_contrast = 0.05,
  gene_name_col = "gene_name",
  output_directory = "/data/lorenzo_delitala/data/project_files/ding/cortex_2",
  file_name = "dtu_candidates.gene_cluster.csv"
)
