library(project.logger)
library(project.cotan)

combine_qc_barcodes <- function(file_list, output_path) {
  all_barcodes <- c()
  
  for (cell_line in names(file_list)) {
    file_path <- file_list[[cell_line]]
    
    if (!file.exists(file_path)) {
      log_warn(sprintf("Warning: file does not exist and will be skipped -> %s", file_path))
      next
    }
    
    data <- read.table(file_path, header = FALSE, stringsAsFactors = FALSE)
    all_barcodes <- c(all_barcodes, data[[1]])
  }
  
  unique_barcodes <- unique(all_barcodes)
  
  write.table(unique_barcodes, file = output_path, 
              sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
  
  invisible(unique_barcodes)
}

config_workflow(logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/logs", 
  file_name = "init_cotan.transcript.log")

log_info("Loading Seurat object...")
seurat_obj <- readRDS("/data/lorenzo_delitala/data/project_files/arrigoni/objects/ready_to_coex.seurat.rds")

cotan_obj <- initialize_cotan_from_seurat(
  seurat_obj,
  geo_id = "GSE243665",
  seq_method = "10xv1",
  condition = "Transcript_Arrigoni"
)

log_info("Building valid cells tsv file...")
base_dir <- "/data/lorenzo_delitala/data/geo_metadata/arrigoni"

tsv_files <- c(
  "A549"       = file.path(base_dir, "GSE243665_A549_barcodes.tsv.gz"),
  "CCL-185-IG" = file.path(base_dir, "GSE243665_CCL-185-IG_barcodes.tsv.gz"),
  "CRL5868"    = file.path(base_dir, "GSE243665_CRL5868_barcodes.tsv.gz"),
  "DV90"       = file.path(base_dir, "GSE243665_DV90_barcodes.tsv.gz"),
  "HCC78"      = file.path(base_dir, "GSE243665_HCC78_barcodes.tsv.gz"),
  "HTB178"     = file.path(base_dir, "GSE243665_HTB178_barcodes.tsv.gz"),
  "PBMCs"      = file.path(base_dir, "GSE243665_PBMCs_barcodes.tsv.gz"),
  "PC9"        = file.path(base_dir, "GSE243665_PC9_barcodes.tsv.gz")
)

output_file_path <- "/data/lorenzo_delitala/data/project_files/arrigoni/GSE243665_combined_QC_barcodes.tsv"

combine_qc_barcodes(tsv_files, output_path = output_file_path)

cotan_obj <- flag_valid_cells_from_tsv(cotan_obj, tsv_file = output_file_path, cond_name = "passed_QC", 
    has_header = FALSE, override = TRUE)

cotan_obj <- filter_cotan_by_condition(cotan_obj, cond_name = "passed_QC", cond_value = TRUE)

cotan_obj <- add_cell_types_from_tsv(cotan_obj, cluster_name = "Known_Cell_Types", tsv_files = tsv_files)

cotan_obj <- add_gene_info_from_t2g(cotan_obj, "/data/lorenzo_delitala/data/genomes/GRCh38/gene_index/index/t2g_3col.tsv", col_name = "gene_id")

cotan_obj <- add_gene_info_from_t2g(cotan_obj, col_name = "gene_name", t2g_file ="/data/lorenzo_delitala/data/project_files/arrigoni/t2gene_name.tsv")

cotan_obj <- clean_cotan_data(cotan_obj, drop_fully_expressed = TRUE,
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/objects", 
  file_name = "initialized.transcript.cotan.rds")