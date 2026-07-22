#!/usr/bin/env Rscript

library(project.base)
library(project.logger)
library(project.cotan)
library(COTAN)

cotan_obj_path <- "/data/lorenzo_delitala/data/test/cotan_coex.rds"

output_dir <- "/data/lorenzo_delitala/data/test"

cotan_obj <- readRDS(cotan_obj_path)

project.logger::config_workflow(logging_level = 3L, output_dir = "/data/lorenzo_delitala/logs")

cotan_obj <- calculate_p_value (cotan_obj, cores = 60L, chunk_size = 512L)

cotan_obj <- dea_on_clusters (cotan_obj, cl_name = "Known_Cell_Types", clusters = NULL)

extract_dtu_candidates(
  cotan_obj,
  clusterization_name = "Known_Cell_Types",
  p_value_threshold = 0.05,
  coex_threshold = -0.1,
  min_dea_contrast = 0.5,
  output_directory = output_dir,
  file_name = "dtu_candidates.csv"
)