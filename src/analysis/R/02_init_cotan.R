#!/usr/bin/env Rscript

# Step 02 — build the COTAN object and attach its cell/gene metadata.
#
# Two input modes, chosen by the config:
#   * `paths.input_seurat` (default): transcript-level runs
#   * `steps.init_cotan.matrix`:       the gene-level run, which starts from the
#                                      GEO count matrix instead of a Seurat object

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

cfg <- load_config()
p <- resolve_paths(cfg)
target <- out_file(p, object_path(p, "initialized"))

matrix_block <- step_cfg(p, "init_cotan", "matrix")
cluster_name <- step_cfg(p, "init_cotan", "cluster_name")
drop_fully_expressed <- isTRUE(step_cfg(p, "init_cotan", "drop_fully_expressed", TRUE))

if (!is.null(matrix_block)) {
  require_paths(p, "input_matrix", "input_matrix_genes", "input_matrix_cells")
  check_io(
    p,
    reads = c(
      "count matrix" = p$input_matrix,
      "gene names" = p$input_matrix_genes,
      "cell barcodes" = p$input_matrix_cells
    ),
    writes = c("initialized cotan" = target)
  )
  step_log(p, log_name(p, "init"))

  log_info("Loading gene count matrix...")
  counts_matrix <- Matrix::readMM(p$input_matrix)
  genes_all <- utils::read.delim(p$input_matrix_genes, header = FALSE, stringsAsFactors = FALSE)
  cells_all <- utils::read.delim(p$input_matrix_cells, header = FALSE, stringsAsFactors = FALSE)

  log_info("Assigning names to the matrix...")
  rownames(counts_matrix) <- genes_all$V1
  colnames(counts_matrix) <- cells_all$V1

  barcode_pattern <- matrix_block$barcode_pattern
  log_info(sprintf("Isolating cells matching '%s'...", barcode_pattern))
  counts_matrix <- counts_matrix[, grep(barcode_pattern, colnames(counts_matrix))]
  colnames(counts_matrix) <- gsub(barcode_pattern, "", colnames(counts_matrix))

  gene_name_pattern <- matrix_block$gene_name_pattern
  if (!is.null(gene_name_pattern)) {
    log_info("Cleaning gene names...")
    rownames(counts_matrix) <- make.unique(gsub(gene_name_pattern, "", rownames(counts_matrix)))
  }

  log_info("Initializing COTAN object...")
  cotan_obj <- COTAN::COTAN(raw = counts_matrix)
  cotan_obj <- COTAN::initializeMetaDataset(
    cotan_obj,
    GEO = cfg$meta$geo_id,
    sequencingMethod = cfg$meta$seq_method,
    sampleCondition = cfg$meta$condition
  )
} else {
  require_paths(p, "input_seurat", "t2g", "t2gene_name")
  ready_seurat <- in_file(p, object_path(p, "ready_seurat"))
  qc_tsv <- if (!is.null(p$cell_type_files)) p$part_qc_tsv else p$valid_cells_tsv
  if (is.null(qc_tsv)) {
    die("this config has neither 'paths: valid_cells_tsv' nor 'paths: cell_type_files'")
  }

  check_io(
    p,
    reads = c(
      "ready seurat object" = ready_seurat,
      "t2g table" = p$t2g,
      "transcript -> gene name" = p$t2gene_name,
      "valid cells tsv" = if (is.null(p$cell_type_files)) p$valid_cells_tsv else NULL,
      "cell type barcodes" = p$cell_type_files
    ),
    writes = c(
      "initialized cotan" = target,
      "combined QC tsv" = if (is.null(p$cell_type_files)) NULL else p$part_qc_tsv
    )
  )
  step_log(p, log_name(p, "init_cotan"))

  log_info(sprintf("Loading Seurat object: %s", ready_seurat))
  seurat_obj <- readRDS(ready_seurat)

  log_info("Initializing COTAN object...")
  cotan_obj <- initialize_cotan_from_seurat(
    seurat_obj,
    geo_id = cfg$meta$geo_id,
    seq_method = cfg$meta$seq_method,
    condition = cfg$meta$condition
  )

  if (!is.null(p$cell_type_files)) {
    log_info("Combining per-cell-line QC barcode files...")
    combine_barcode_files(p$cell_type_files, qc_tsv)
  }

  log_info("Flagging cells that passed QC...")
  cotan_obj <- flag_valid_cells_from_tsv(
    cotan_obj,
    tsv_file = qc_tsv,
    cond_name = "passed_QC",
    has_header = FALSE,
    override = TRUE
  )
  cotan_obj <- filter_cotan_by_condition(cotan_obj, cond_name = "passed_QC", cond_value = TRUE)

  if (!is.null(cluster_name) && !is.null(p$cell_type_files)) {
    log_info(sprintf("Adding cell types as clusterization '%s'...", cluster_name))
    cotan_obj <- add_cell_types_from_tsv(
      cotan_obj,
      cluster_name = cluster_name,
      tsv_files = p$cell_type_files
    )
  }

  log_info("Adding gene metadata from the t2g tables...")
  cotan_obj <- add_gene_info_from_t2g(cotan_obj, t2g_file = p$t2g, col_name = "gene_id")
  cotan_obj <- add_gene_info_from_t2g(cotan_obj, t2g_file = p$t2gene_name, col_name = "gene_name")
}

log_info("Cleaning the COTAN object...")
cotan_obj <- clean_cotan_data(
  cotan_obj,
  drop_fully_expressed = drop_fully_expressed,
  output_dir = dirname(target),
  file_name = basename(target)
)
