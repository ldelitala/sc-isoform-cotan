library(COTAN)
library(project.logger)

config_workflow(
  logging_level = 3L, 
  output_dir = "/data/lorenzo_delitala/data/project_files/ding/cortex_2/logs", 
  file_name = "transfer_clusters.log"
)

log_header("Transfer Gene Clusters to Transcripts")

log_info("Loading COTAN objects...")
cotan_genes <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/clustered.gene.rds")
cotan_transcripts <- readRDS("/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/clustered.transcript.rds")

log_info("Extracting gene clusters...")
clusters_genes <- getClusters(cotan_genes, clName = "local_gene_cluster")

log_info("Extracting transcript cells...")
cells_transcripts <- getCells(cotan_transcripts)

log_info("Mapping gene clusters to transcript cells...")
transferred_clusters <- setNames(rep("-1", length(cells_transcripts)), cells_transcripts)
common_cells <- intersect(names(clusters_genes), cells_transcripts)

transferred_clusters[common_cells] <- as.character(clusters_genes[common_cells])
transferred_clusters <- as.factor(transferred_clusters)

log_stat(sprintf("Successfully mapped %d common cells.", length(common_cells)))
log_stat(sprintf("Assigned %d cells to noise/unclustered (-1).", length(cells_transcripts) - length(common_cells)))

log_info("Injecting gene clusterization into the transcript object...")
cotan_transcripts <- addClusterization(
  objCOTAN = cotan_transcripts,
  clName = "local_gene_cluster",
  clusters = transferred_clusters,
  coexDF = data.frame(),
  override = TRUE
)

output_path <- "/data/lorenzo_delitala/data/project_files/ding/cortex_2/objects/clustered.transcript.with_gene_labels.rds"
log_info(sprintf("Saving updated transcript object to: %s", output_path))
saveRDS(cotan_transcripts, output_path)

log_header(is_complete = TRUE)