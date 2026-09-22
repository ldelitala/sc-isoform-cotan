library(COTAN)
library(project.logger)
suppressPackageStartupMessages({
    library(mclust)
    library(ComplexHeatmap)
})

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", 
  file_name = "compare_clusters.log"
)

log_info("Loading COTAN objects...")
cotan_genes <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/clustered.gene.rds")
cotan_transcripts <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/clustered.transcript.rds")

log_info("Checking available clusterizations...")
avail_cl_genes <- getClusterizations(cotan_genes)
avail_cl_transcripts <- getClusterizations(cotan_transcripts)

log_stat(sprintf("Available clusterizations in genes object: %s", paste(avail_cl_genes, collapse = ", ")))
log_stat(sprintf("Available clusterizations in transcripts object: %s", paste(avail_cl_transcripts, collapse = ", ")))

log_info("Extracting clusters from the COTAN objects...")
clusters_genes <- getClusters(cotan_genes, clName = "local_gene_cluster")
clusters_transcripts <- getClusters(cotan_transcripts, clName = "merged")

log_info("Finding common cells (barcodes) to align the two clusterizations...")
common_cells <- intersect(names(clusters_genes), names(clusters_transcripts))
log_info(sprintf("Found %d common cells between the two objects.", length(common_cells)))

clusters_genes_aligned <- clusters_genes[common_cells]
clusters_transcripts_aligned <- clusters_transcripts[common_cells]

log_info("Calculating the confusion matrix for the aligned cells...")
overlap_matrix <- table(
  Genes = clusters_genes_aligned,
  Transcripts = clusters_transcripts_aligned
)

log_info("Confusion matrix calculated successfully. Printing matrix to console:")
print(overlap_matrix)

plot_dir <- "/data/lorenzo_delitala/data/project_files/ding/cortex_2/plots"
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

heatmap_path <- file.path(plot_dir, "heatmap_genes_vs_transcripts.pdf")
log_info("Generating heatmap...")
log_stat(sprintf("Saving heatmap to: %s", heatmap_path))

pdf(heatmap_path, width = 8, height = 6)

ht <- Heatmap(
  matrix = as.matrix(overlap_matrix),
  name = "N. Cells",
  column_title = "Transcript Clusters",
  row_title = "Gene Clusters",
  cluster_rows = FALSE, 
  cluster_columns = FALSE,
  cell_fun = function(j, i, x, y, width, height, fill) {
    grid.text(sprintf("%d", overlap_matrix[i, j]), x, y, gp = gpar(fontsize = 10))
  }
)

draw(ht)
dev.off()
log_info("Heatmap successfully saved.")

log_info("Calculating the Adjusted Rand Index (ARI) to evaluate cluster similarity...")
ari_score <- adjustedRandIndex(clusters_genes_aligned, clusters_transcripts_aligned)
log_stat(sprintf("Adjusted Rand Index (ARI) score: %.4f", ari_score))

log_info("Script execution completed.")