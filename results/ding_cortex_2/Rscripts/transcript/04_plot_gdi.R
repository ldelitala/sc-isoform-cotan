library(project.logger)
library(project.cotan)
library(COTAN)
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

npg_genes <- c("Nes", "Vim", "Sox2", "Sox1", "Notch1", "Hes1", "Hes5", "Pax6")
png_genes <- c("Map2", "Tubb3", "Neurod1", "Nefm", "Nefl", "Dcx", "Tbr1")
hk_genes  <- c("Calm1", "Cox6b1", "Ppia", "Rpl18", "Cox7c", "Erh", "H3f3a",
               "Taf1", "Taf2", "Gapdh", "Actb", "Golph3", "Zfr", "Sub1", "Tars", "Amacr")

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", 
  file_name = "plot_gdi.log"
)

log_info("Loading Cotan object with gdi...")
cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/calculated.transcript.cotan.rds")

log_info("Finding valid group markers for cotan object...")
genes_info <- COTAN::getMetadataGenes(cotan_obj)
genes_info$transcript_id <- rownames(genes_info)

groupMarkers <- list(
  "NPGs" = genes_info %>% filter(gene_name %in% npg_genes) %>% pull(transcript_id),
  "PNGs" = genes_info %>% filter(gene_name %in% png_genes) %>% pull(transcript_id),
  "HK"   = genes_info %>% filter(gene_name %in% hk_genes)  %>% pull(transcript_id)
)

log_info("Transcript found:")
log_stat(paste0("NPGs: ", length(groupMarkers$NPGs), " transcripts"))
log_stat(paste0("PNGs: ", length(groupMarkers$PNGs), " transcripts"))
log_stat(paste0("HK:   ", length(groupMarkers$HK),   " transcripts"))

log_cotan_execution("GDIPlot()", condition = "Cortex2_transcripts", GDIThreshold = 1.5)
gdi_plot <- COTAN::GDIPlot(
  objCOTAN = cotan_obj, 
  genes = groupMarkers,
  condition = "Cortex2_transcripts",
  GDIThreshold = 1.5
)
log_cotan_execution(is_complete = TRUE)


output_png <- "/data/lorenzo_delitala/data/project_files/ding/cortex_2/plots/GDI_transcript_plot_markers.png"

log_info("Saving GDI plot...")
ggsave(
  filename = output_png,
  plot = gdi_plot,
  width = 11,
  height = 8,
  dpi = 300
)

log_stat(sprintf("GDI plot saved at: %s", output_png))
