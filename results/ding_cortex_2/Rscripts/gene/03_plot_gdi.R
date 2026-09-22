suppressPackageStartupMessages({
  library(ggplot2)
})
library(project.logger)
library(project.cotan)

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", 
  file_name = "plot_gdi.gene.log"
)

log_info("Uploading COTAN object...")
cotan_obj <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/calculated.gene.cotan.rds")


groupMarkers <- list(
  "NPGs" = c("Nes", "Vim", "Sox2", "Sox1", "Notch1", "Hes1", "Hes5", "Pax6"),
  "PNGs" = c("Map2", "Tubb3", "Neurod1", "Nefm", "Nefl", "Dcx", "Tbr1"),
  "HK"   = c("Calm1", "Cox6b1", "Ppia", "Rpl18", "Cox7c", "Erh", "H3f3a",
               "Taf1", "Taf2", "Gapdh", "Actb", "Golph3", "Zfr", "Sub1", "Tars", "Amacr")
)

for (group_name in names(groupMarkers)) {
  genes <- groupMarkers[[group_name]]
  log_stat(sprintf("'%s' [%d genes]: %s", 
                   group_name, 
                   length(genes), 
                   paste(genes, collapse = ", ")))
}

log_cotan_execution("GDIPlot()", condition = "Cortex2_genes", GDIThreshold = 0.3)
gdi_plot <- COTAN::GDIPlot(
  objCOTAN = cotan_obj, 
  genes = groupMarkers,
  condition = "Cortex2_genes",
)
log_cotan_execution(is_complete = TRUE)

output_png <- "/data/lorenzo_delitala/data/project_files/ding/cortex_2/plots/GDI_genes_plot_markers.png"

log_info("Saving graph...")
ggsave(
  filename = output_png,
  plot = gdi_plot,
  width = 11,
  height = 8,
  dpi = 300
)
log_stat(sprintf("Graph successfully saved at: %s", output_png))

