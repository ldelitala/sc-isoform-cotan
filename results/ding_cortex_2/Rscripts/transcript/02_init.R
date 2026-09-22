library(project.logger)
library(project.cotan)
library(COTAN)


seurat_obj <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/ready_to_cotan.transcript.seurat.rds")

config_workflow(logging_level = 3L, output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", file_name = "init_cotan.transcript.log")

cotan_obj <- initialize_cotan_from_seurat(
  seurat_obj,
  geo_id = "GSE132044",
  seq_method = "10XV2",
  condition = "Ding_Cortex_2_Transcript"
)

cotan_obj <- flag_valid_cells_from_tsv(cotan_obj, 
    tsv_file = "/data/lorenzo_delitala/data/geo_metadata/ding/cortex_2/clean_Cortex2_QC_barcodes.tsv.gz", cond_name = "passed_QC", 
    has_header = FALSE, override = TRUE)

cotan_obj <- filter_cotan_by_condition(cotan_obj, cond_name = "passed_QC", cond_value = TRUE)

cotan_obj <- add_gene_info_from_t2g(cotan_obj, col_name = "gene_id", t2g_file = "/data/lorenzo_delitala/data/genomes/GRCm39/gene_index/index/t2g_3col.tsv")

cotan_obj <- add_gene_info_from_t2g(cotan_obj, col_name = "gene_name", t2g_file ="/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/t2gene_name.tsv")

cotan_obj <- clean_cotan_data(cotan_obj, drop_fully_expressed = TRUE,
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects", file_name = "initialized.transcript.cotan.rds")
