#!/usr/bin/env Rscript

# FILE NAME: clean.R

# 0. temp hardcoding of paths
output_dir <- "./results/cotan_data"
log_file_name <- "clean.log"
filtered_data <- "/data/lorenzo_delitala/runs/arrigoni2023/results/sample_filtered.rds"

# 1. Load the shared configuration
source("/data/lorenzo_delitala/src/pipeline/bin/lib_COTAN_config.R")

normalized_output_dir <- config_cotan_workflow(output_dir, log_file_name)

# 2. load matrix data
filtered_data <- readRDS(filtered_data)

if (is.list(filtered_data) && "matrix" %in% names(filtered_data)) {
  message("Extracting sparse matrix from list...")
  filtered_matrix <- filtered_data$matrix
} else {
  stop("The loaded data does not contain a 'matrix' key. Check your filtering script output!")
}

# 3. create COTAN object and set MetaData
cotan_obj <- COTAN(raw = filtered_matrix)
cotan_obj <-
  initializeMetaDataset(
    cotan_obj,
    GEO = "SRA: SRR26127904-SRR26127911",
    sequencingMethod = "10Xv3",
    sampleCondition = "arrigoni2023"
  )

logThis(
        paste0(
               "Condition ",
               getMetadataElement(cotan_obj, datasetTags()[["cond"]])),
        logLevel = 1L)

colnames(filtered_matrix)[1:5]