library(project.logger)
library(project.seurat)

seurat_obj <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/raw_matrix.seurat.rds")

config_workflow(logging_level = 3L, output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", file_name = "prepare_seurat.transcript.log")

seurat_obj <- clean_simpleaf_barcodes(seurat_obj)

seurat_obj <- filter_spliced_transcripts(seurat_obj, prefix = "^ENSMUST")

seurat_obj <- round_seurat_counts(seurat_obj, 
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects", 
  file_name = "ready_to_cotan.transcript.seurat.rds")