library(project.logger)
library(project.cotan)
library(COTAN)
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

hk_genes <- c("B2M", "RPL13A") #"GAPDH", "ACTB"
pbmc_genes <- c("PTPRC", "CD3D", "CD79A", "CD14")
epi_lung_genes <- c("EPCAM", "KRT8", "NKX2-1")
tumor_lines_genes <- c("EGFR", "KRAS", "ALK", "VIM", "MET")

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/arrigoni/logs", 
  file_name = "plot_gdi.transcript.log"
)

log_info("Loading Cotan object with gdi...")
cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/arrigoni/objects/calculated.transcript.cotan.rds")

log_info("Finding valid group markers for cotan object...")
genes_info <- COTAN::getMetadataGenes(cotan_obj)
genes_info$transcript_id <- rownames(genes_info)

groupMarkers <- list(
  "Housekeeping"      = genes_info %>% filter(gene_name %in% hk_genes)          %>% pull(transcript_id),
  "PBMCs"             = genes_info %>% filter(gene_name %in% pbmc_genes)        %>% pull(transcript_id),
  "Epithelial_Lung"   = genes_info %>% filter(gene_name %in% epi_lung_genes)    %>% pull(transcript_id),
  "Tumor_Lines_Panel" = genes_info %>% filter(gene_name %in% tumor_lines_genes) %>% pull(transcript_id)
)

log_info("Transcript found:")
log_stat(paste0("Housekeeping:      ", length(groupMarkers$Housekeeping),      " transcripts"))
log_stat(paste0("PBMCs:             ", length(groupMarkers$PBMCs),             " transcripts"))
log_stat(paste0("Epithelial_Lung:   ", length(groupMarkers$Epithelial_Lung),   " transcripts"))
log_stat(paste0("Tumor_Lines_Panel: ", length(groupMarkers$Tumor_Lines_Panel), " transcripts"))

log_cotan_execution("GDIPlot()", condition = "Cortex2_transcripts", GDIThreshold = 1.5)
gdi_plot <- COTAN::GDIPlot(
  objCOTAN = cotan_obj, 
  genes = groupMarkers,
  condition = "Cortex2_transcripts",
  GDIThreshold = 1.5
)
log_cotan_execution(is_complete = TRUE)

log_info("Saving GDI plot...")
output_png <- "/data/lorenzo_delitala/data/project_files/arrigoni/plots/GDI_transcript_plot_markers.png"
ggsave(
  filename = output_png,
  plot = gdi_plot,
  width = 11,
  height = 8,
  dpi = 300
)

log_stat(sprintf("GDI plot saved at: %s", output_png))