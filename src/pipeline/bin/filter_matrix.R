#!/usr/bin/env Rscript

# filter_matrix.R
# Main driver script for single-cell raw matrix filtering.
# Supports both raw Alevin folders (single or multiple) and RDS files (Seurat or SCE).
#
# Usage:
#   Rscript scripts/filter_matrix.R -i <input_path> -o <output_dir> -s <sample_name> --min_features 200 ...

suppressPackageStartupMessages({
  library(optparse)
  library(Matrix)
})

# Source modules relative to script directory
initial_options <- commandArgs(trailingOnly = FALSE)
script_name <- sub("--file=", "", initial_options[grep("--file=", initial_options)])
script_dir <- if (length(script_name) > 0) dirname(normalizePath(script_name)) else "."

source(file.path(script_dir, "lib_io.R"))
source(file.path(script_dir, "lib_qc.R"))

# Parse CLI options
option_list <- list(
  make_option(c("-i", "--input_path"), type = "character", default = NULL,
              help = "Path to combined RDS file (.seurat.rds / .sce.rds) or alevin dir", metavar = "character"),
  make_option(c("-o", "--output_dir"), type = "character", default = "./filtered",
              help = "Directory where filtered matrix will be saved [default= %default]", metavar = "character"),
  make_option(c("-s", "--sample_name"), type = "character", default = "sample",
              help = "Sample name prefix for output files [default= %default]", metavar = "character"),
  make_option(c("-t", "--input_type"), type = "character", default = "auto",
              help = "Input type override: 'auto', 'alevin', 'seurat', 'sce' [default= %default]", metavar = "character"),
  
  # QC Threshold options
  make_option(c("--min_features"), type = "integer", default = 200,
              help = "Minimum features per cell [default= %default]", metavar = "integer"),
  make_option(c("--max_features"), type = "integer", default = 8000,
              help = "Maximum features per cell [default= %default]", metavar = "integer"),
  make_option(c("--min_counts"), type = "integer", default = 500,
              help = "Minimum counts per cell [default= %default]", metavar = "integer"),
  make_option(c("--max_percent_mt"), type = "double", default = 10.0,
              help = "Maximum percent mitochondrial reads [default= %default]", metavar = "double"),
  make_option(c("--mt_transcripts"), type = "character", default = NULL,
              help = "Path to text file containing mitochondrial transcript Ensembl IDs", metavar = "character")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

if (is.null(opt$input_path)) {
  print_help(opt_parser)
  stop("Input path must be specified via -i or --input_path.", call. = FALSE)
}

# 1. Load Mitochondrial Transcript IDs if provided
mt_ids <- NULL
if (!is.null(opt$mt_transcripts) && file.exists(opt$mt_transcripts)) {
  message("Loading mitochondrial transcript IDs from: ", opt$mt_transcripts)
  mt_ids <- readLines(opt$mt_transcripts)
  message("Loaded ", length(mt_ids), " mitochondrial transcript IDs.")
} else if (!is.null(opt$mt_transcripts)) {
  warning("Specified mt_transcripts file does not exist: ", opt$mt_transcripts)
}

# 2. Load Raw Matrix (uses lib_io)
raw_matrix <- load_raw_matrix(opt$input_path, opt$input_type)

message("Raw dimensions: ", nrow(raw_matrix), " transcripts/genes, ", ncol(raw_matrix), " cells.")

# 3. Calculate QC Metrics (uses lib_qc, passing mt_ids for transcript matching)
cell_metadata <- calculate_qc_metrics(raw_matrix, mt_ids)

# 4. Filter Cells (uses lib_qc)
filtered_data <- filter_cells(
  raw_matrix, 
  cell_metadata, 
  opt$min_features, 
  opt$max_features, 
  opt$min_counts, 
  opt$max_percent_mt
)

# 5. Save Outputs (uses lib_qc)
save_filtered_matrix(filtered_data, opt$output_dir, opt$sample_name)

message("QC Filtering completed successfully!")

