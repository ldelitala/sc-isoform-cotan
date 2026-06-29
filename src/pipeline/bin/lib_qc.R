# lib_qc.R
# QC and filtering library for single-cell raw matrices

# Calculate cell QC metrics (nFeatures, nCounts, percent_mt)
# Accepts optional mt_ids vector for transcript-level matches
calculate_qc_metrics <- function(raw_matrix, mt_ids = NULL) {
  message("Calculating cell QC metrics...")
  
  detected_features_per_cell <- colSums(raw_matrix > 0)
  total_counts_per_cell      <- colSums(raw_matrix)
  
  # Identify mitochondrial genes/transcripts
  if (!is.null(mt_ids) && length(mt_ids) > 0) {
    message("Finding mitochondrial transcripts using provided IDs list...")
    mitochondrial_transcripts <- intersect(rownames(raw_matrix), mt_ids)
  } else {
    message("Finding mitochondrial genes using regex match pattern...")
    mitochondrial_transcripts <- grep("^MT-|^mt-", rownames(raw_matrix), value = TRUE)
  }
  
  message("Found ", length(mitochondrial_transcripts), " mitochondrial transcripts in the expression matrix.")
  
  percent_mitochondrial_reads <- if (length(mitochondrial_transcripts) > 0) {
    raw_ratio <- colSums(raw_matrix[mitochondrial_transcripts, , drop = FALSE]) / total_counts_per_cell * 100
    raw_ratio[total_counts_per_cell == 0] <- 0
    raw_ratio
  } else {
    rep(0, ncol(raw_matrix))
  }
  
  cell_metadata <- data.frame(
    barcode = colnames(raw_matrix),
    nFeatures = detected_features_per_cell,
    nCounts = total_counts_per_cell,
    percent_mt = percent_mitochondrial_reads,
    stringsAsFactors = FALSE
  )
  
  return(cell_metadata)
}

# Apply QC thresholds to cell matrix and metadata
filter_cells <- function(raw_matrix, cell_metadata, min_features, max_features, min_counts, max_percent_mt) {
  message("Filtering cells based on thresholds:")
  message("  min_features:   ", min_features)
  message("  max_features:   ", max_features)
  message("  min_counts:     ", min_counts)
  message("  max_percent_mt: ", max_percent_mt, "%")
  
  cells_passing_qc <- (cell_metadata$nFeatures >= min_features) &
                      (cell_metadata$nFeatures <= max_features) &
                      (cell_metadata$nCounts >= min_counts) &
                      (cell_metadata$percent_mt <= max_percent_mt)
  
  message("Filtering summary:")
  message("  Cells kept: ", sum(cells_passing_qc), " out of ", length(cells_passing_qc))
  
  filtered_matrix <- raw_matrix[, cells_passing_qc, drop = FALSE]
  filtered_metadata <- cell_metadata[cells_passing_qc, ]
  
  return(list(
    matrix = filtered_matrix,
    metadata = filtered_metadata
  ))
}

# Save filtered matrix output RDS file
save_filtered_matrix <- function(filtered_data, output_dir, sample_name) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  rds_path <- file.path(output_dir, paste0(sample_name, "_filtered.rds"))
  message("Saving results to: ", rds_path)
  saveRDS(filtered_data, file = rds_path)
}
