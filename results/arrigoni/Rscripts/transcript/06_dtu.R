library(project.logger)
library(project.cotan)

config_workflow(logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/logs", 
  file_name = "cotan_calc.transcript.log")

log_info("Loading Cotan object...")
cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/arrigoni/calculated.cotan.rds")

cotan_obj <- dea_on_clusters (cotan_obj, cl_name = "Known_Cell_Types", clusters = NULL)

cotan_obj <- extract_dtu_candidates(
  cotan_obj,
  clusterization_name = "Known_Cell_Types",
  p_value_threshold = 0.05,
  min_dea_contrast = 0.2,
  gene_name_col = "gene_name",
  output_directory = "/data/lorenzo_delitala/data/project_files/arrigoni",
  file_name = "dtu_candidates.known_cell_types.csv"
)

cotan_obj <- dea_on_clusters (cotan_obj, cl_name = "local_transcript_cluster", clusters = NULL)

cotan_obj <- extract_dtu_candidates(
  cotan_obj,
  clusterization_name = "local_transcript_cluster",
  p_value_threshold = 0.05,
  min_dea_contrast = 0.2,
  gene_name_col = "gene_name",
  output_directory = "/data/lorenzo_delitala/data/project_files/arrigoni",
  file_name = "dtu_candidates.local_transcritp_cluster.csv"
)
