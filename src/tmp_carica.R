#!/usr/bin/env Rscript

library(project.base)
library(project.logger)
library(project.cotan)
library(project.seurat)

# TEMPORARY HARDCODING OF PATHS
combined_raw_matrix_path <-
  "/data/lorenzo_delitala/runs/arrigoni2023/results/combined_raw_matrix.seurat.rds"

mt_transcript_list_path <-
  "/data/lorenzo_delitala/runs/arrigoni2023/results/transcript_index/index/mt_transcripts.txt"

t2g_path <- 
  "/data/lorenzo_delitala/runs/arrigoni2023/results/gene_index/index/t2g_3col.tsv"

output_dir <- "/data/lorenzo_delitala/data/test"

file_name <- "b2sample.tsv"

mt_transcripts_list <- readLines(mt_transcript_list_path)

mt_transcripts_list <- trimws(mt_transcripts_list)

seurat_obj <- readRDS(combined_raw_matrix_path)

config_workflow(logging_level = 3L, output_dir = "/data/lorenzo_delitala/logs")

seurat_obj <- clean_simpleaf_barcodes(seurat_obj, output_dir = output_dir, file_name = file_name)

seurat_obj <- filter_spliced_transcripts(seurat_obj)

seurat_obj <- round_seurat_counts(seurat_obj)

cotan_obj <- initialize_cotan_from_seurat(
  seurat_obj,
  geo_id = "GSE243665",
  seq_method = "10xv1",
  condition = "Arrigoni2023"
)

tsv_path <- file.path(output_dir, file_name)

cotan_obj <- add_origin_samples(cotan_obj, b2sample_tsv = tsv_path)

base_dir <- "runs/arrigoni2023/geo_metadata/"

tsv_files <- c(
  "A549"       = paste0(base_dir, "GSE243665_A549_barcodes.tsv.gz"),
  "CCL-185-IG" = paste0(base_dir, "GSE243665_CCL-185-IG_barcodes.tsv.gz"),
  "CRL5868"    = paste0(base_dir, "GSE243665_CRL5868_barcodes.tsv.gz"),
  "DV90"       = paste0(base_dir, "GSE243665_DV90_barcodes.tsv.gz"),
  "HCC78"      = paste0(base_dir, "GSE243665_HCC78_barcodes.tsv.gz"),
  "HTB178"     = paste0(base_dir, "GSE243665_HTB178_barcodes.tsv.gz"),
  "PBMCs"      = paste0(base_dir, "GSE243665_PBMCs_barcodes.tsv.gz"),
  "PC9"        = paste0(base_dir, "GSE243665_PC9_barcodes.tsv.gz")
)


source("/data/lorenzo_delitala/src/pipeline/bin/tmp_create_tsv.R")

cotan_obj <- flag_valid_cells_from_tsv(cotan_obj, tsv_file = output_file, has_header = FALSE)

cotan_obj <- filter_cotan_by_condition(cotan_obj, "passed_QC", TRUE)

cotan_obj <- clean_cotan_data(cotan_obj, cells_cutoff = 0.001, genes_cutoff = 0.002)

cotan_obj <- add_cell_types_from_tsv(cotan_obj, cluster_name = "Known_Cell_Types", tsv_files = tsv_files)

cotan_obj <- add_gene_info_from_t2g(cotan_obj, t2g_path)

cotan_obj <- prepare_to_coex(cotan_obj, cores = 80L, chunk_size = 512L)

cotan_obj <- calculate_coex(cotan_obj, return_pp_fract = TRUE, device_str = "cpu", output_dir = output_dir)

cotan_obj <- calculate_p_value (cotan_obj)

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