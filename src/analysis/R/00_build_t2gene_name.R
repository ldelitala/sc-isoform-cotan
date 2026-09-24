#!/usr/bin/env Rscript

# Step 00 — rebuild the transcript -> gene-name map used as COTAN gene metadata.

initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."
source(file.path(script_dir, "..", "lib", "common.R"))

cfg <- load_config()
p <- resolve_paths(cfg)
require_paths(p, "t2g", "gene_id_to_name", "t2gene_name")
target <- out_file(p, p$t2gene_name)

check_io(
  p,
  reads = c("t2g table" = p$t2g, "gene id -> name table" = p$gene_id_to_name),
  writes = c("transcript -> gene name" = target)
)
step_log(p, log_name(p, "build_t2gene_name"))

log_info("Reading t2g tables...")
t2g <- utils::read.delim(p$t2g, header = FALSE, stringsAsFactors = FALSE)[, 1:2]
names(t2g) <- c("transcript_id", "gene_id")

gene_names <- utils::read.delim(p$gene_id_to_name, header = FALSE, stringsAsFactors = FALSE)[, 1:2]
names(gene_names) <- c("gene_id", "gene_name")

log_info("Joining transcript ids to gene names...")
# match() keeps the t2g row order, like the dplyr left_join + distinct it replaces
t2gene_name <- data.frame(
  transcript_id = t2g$transcript_id,
  gene_name = gene_names$gene_name[match(t2g$gene_id, gene_names$gene_id)],
  stringsAsFactors = FALSE
)
t2gene_name <- unique(t2gene_name)

log_info(sprintf("Writing %s", target))
utils::write.table(
  t2gene_name,
  file = target,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE,
  col.names = FALSE
)

log_stat(sprintf("Transcripts mapped: %d", nrow(t2gene_name)))
log_stat(sprintf("Transcripts without a gene name: %d", sum(is.na(t2gene_name$gene_name))))
