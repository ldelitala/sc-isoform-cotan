library(Matrix)
library(COTAN)
library(project.logger)
library(project.cotan)


count_matrix_path <- "/data/lorenzo_delitala/data/geo_metadata/ding/cortex_2/GSE132044_cortex_mm10_count_matrix.mtx.gz"
genes_names_path <- "/data/lorenzo_delitala/data/geo_metadata/ding/cortex_2/GSE132044_cortex_mm10_gene.tsv.gz"
cells_names_path <- "/data/lorenzo_delitala/data/geo_metadata/ding/cortex_2/GSE132044_cortex_mm10_cell.tsv.gz.1"

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", 
  file_name = "init.gene.log"
)

log_stat(sprintf("Count Matrix path: %s", count_matrix_path))
log_stat(sprintf("Genes names path: %s", genes_names_path))
log_stat(sprintf("Cells barcodes path: %s", cells_names_path))

log_info("Loading Gene Matrix data...")
counts_matrix <- readMM(count_matrix_path)
genes_all <- read.delim(genes_names_path, header = FALSE, stringsAsFactors = FALSE)
cells_all <- read.delim(cells_names_path, header = FALSE, stringsAsFactors = FALSE)

log_info("Assigning names to matrix...")
rownames(counts_matrix) <- genes_all$V1
colnames(counts_matrix) <- cells_all$V1

log_info("Isolating \"Cortex2 10x-Chromium-V2\" cells...")
sub_matrix <- counts_matrix[, grep("Cortex2\\.10x-Chromium-v2\\.", colnames(counts_matrix))]

log_info("Cleaning names...")
clean_barcodes <- gsub(".*Cortex2\\.10x-Chromium-v2\\.", "", colnames(sub_matrix))
colnames(sub_matrix) <- clean_barcodes

clean_genes <- gsub(".*_", "", rownames(sub_matrix))
rownames(sub_matrix) <- make.unique(clean_genes)

log_info("Initializing COTAN object...")
cotan_obj <- COTAN(raw = sub_matrix)

log_cotan_execution("initializeMetaDataset()", GEO = "GSE132044", sequencingMethod = "10XV2", sampleCondition = "Cortex2")
cotan_obj <- initializeMetaDataset(
    cotan_obj,
    GEO = "GSE132044",
    sequencingMethod = "10XV2",
    sampleCondition = "Ding_Cortex2_Gene"
  )
log_cotan_execution(is_complete = TRUE)

log_matrix_stats(
  cells_before = getNumCells(cotan_obj),
  features_before = getNumGenes(cotan_obj),
)

cotan_obj <- clean_cotan_data(cotan_obj, drop_fully_expressed = TRUE,
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects", 
  file_name = "cleaned.gene.cotan.rds")



