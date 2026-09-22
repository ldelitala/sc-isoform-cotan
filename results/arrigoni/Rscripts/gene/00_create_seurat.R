# Carica le librerie necessarie
library(Seurat)
library(Matrix)
library(project.logger)

config_workflow(logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/logs", 
  file_name = "create_seurat.gene.log")


input_dir <- "/data/lorenzo_delitala/data/geo_metadata/arrigoni/"
output_dir <- "/data/lorenzo_delitala/data/project_files/arrigoni/objects"

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

samples <- c("A549", "CCL-185-IG", "CRL5868", "DV90", "HCC78", "HTB178", "PBMCs", "PC9")

log_info('Loading cells type matrices...')
seurat_list <- list()

for (sample in samples) {
  log_stat(sprintf("Processing: %s", sample))
  
  mtx_file <- file.path(input_dir, paste0("GSE243665_", sample, "_matrix.mtx.gz"))
  cells_file <- file.path(input_dir, paste0("GSE243665_", sample, "_barcodes.tsv.gz"))
  features_file <- file.path(input_dir, paste0("GSE243665_", sample, "_features.tsv.gz"))
  
  counts <- ReadMtx(mtx = mtx_file, 
                    cells = cells_file, 
                    features = features_file, 
                    feature.column = 2)
  
  seurat_obj <- CreateSeuratObject(counts = counts, project = sample)
  
  seurat_list[[sample]] <- seurat_obj
}

log_info("All matrices where loaded.")
log_info("Merging...")

merged_seurat <- merge(x = seurat_list[[1]], 
                       y = seurat_list[-1], 
                       add.cell.ids = samples, 
                       project = "GSE243665_Experiment")

log_info("Cleaning RAM...")
rm(seurat_list, counts, seurat_obj)
gc()

log_info("Saving Seurat object...")
output_file <- file.path(output_dir, "cleaned_matrix.gene.seurat.rds")
saveRDS(merged_seurat, file = output_file)
