library(project.logger)
library(project.seurat)

config_workflow(logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/logs", 
  file_name = "prepare_seurat.transcript.log")

log_info("Loading Seurat object...")
seurat_obj <- readRDS("/data/lorenzo_delitala/data/project_files/arrigoni/raw_matrix.seurat.rds")

seurat_obj <- clean_simpleaf_barcodes(seurat_obj)

seurat_obj <- filter_spliced_transcripts(seurat_obj)

seurat_obj <- round_seurat_counts(seurat_obj, 
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/objects", 
  file_name = "ready_to_coex.seurat.rds")
