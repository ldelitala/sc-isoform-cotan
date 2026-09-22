# ==============================================================================
# Internal Helper Functions
# ==============================================================================

#' Identify Non-Empty Droplets/Cells in a Count Matrix
#'
#' @param counts_mat A matrix containing raw counts (typically dgCMatrix or dense).
#' @return A logical vector of length `ncol(counts_mat)`.
#' @noRd
.not_empty_droplets <- function(counts_mat) {
    if (inherits(counts_mat, "dgCMatrix")) {
        valid_cells <- diff(counts_mat@p) > 0
    } else {
        valid_cells <- Matrix::colSums(counts_mat) > 0
    }
    return(valid_cells)
}

#' Identify Cells with Non-Zero Expression for a Subset of Features
#'
#' Evaluates column pointers directly for `dgCMatrix` to avoid memory copies.
#'
#' @param seurat_obj A `Seurat` object.
#' @param features Character vector of features to evaluate.
#' @param assay Character. The assay to query. Default is "RNA".
#' @param layer Character. The layer to query. Default is "counts".
#' @return A logical vector of length `ncol(seurat_obj)`.
#' @noRd
.find_non_empty_cells <- function(seurat_obj, features, assay = "RNA", layer = "counts") {
    counts_mat <- Seurat::GetAssayData(seurat_obj, assay = assay, layer = layer)

    if (inherits(counts_mat, "dgCMatrix")) {
        subset_mat <- counts_mat[rownames(counts_mat) %in% features, , drop = FALSE]
        valid_cells <- diff(subset_mat@p) > 0
    } else {
        # Fallback for dense matrices
        valid_cells <- Matrix::colSums(counts_mat[features, , drop = FALSE]) > 0
    }

    return(valid_cells)
}

#' Log Variation/Change in Seurat Object Dimensions
#'
#' Wrapper around `log_matrix_stats` to easily display filtering progression.
#'
#' @param before_obj The `Seurat` object before filtering.
#' @param after_obj The `Seurat` object after filtering.
#' @param level Integer. Log level threshold. Default is 1L.
#' @noRd
.log_seurat_change <- function(before_obj, after_obj, level = 1L) {
    log_matrix_stats(
        cells_before = ncol(before_obj),
        cells_after = ncol(after_obj),
        features_before = nrow(before_obj),
        features_after = nrow(after_obj),
        level = level
    )
}
#' Clean simpleaf Cell Names and Export Barcode Mapping
#'
#' Standardizes cell names in a Seurat object generated from simpleaf in nf-core/scrnaseq by
#' removing the sample suffix and resolving duplicates using `make.unique`.
#' Extracts the sample name and exports a 2-column TSV (Barcode, Sample).
#'
#' @param seurat_obj A `Seurat` object.
#' @param output_dir Character. Optional directory to save the `b2sample.tsv` file.
#' @param file_name Character. Name of the output TSV mapping file. Default is `"b2sample.tsv"`.
#'
#' @return A renamed `Seurat` object.
#'
#' @importFrom SeuratObject Cells RenameCells
#' @export
clean_simpleaf_barcodes <- function(
  seurat_obj,
  output_dir = NULL,
  file_name = "b2sample.tsv"
) {
    log_header("clean simpleaf barcodes")

    original_names <- SeuratObject::Cells(seurat_obj)

    if (!any(grepl("_", original_names))) {
        log_warn("No underscores found in cell names. Barcodes might already be clean. Skipping renaming.")
        log_header(is_complete = TRUE)
        return(seurat_obj)
    }

    log_info("Processing cell names...")

    # Estrai barcode pulito e sample
    raw_barcodes <- sub("_.*", "", original_names)
    samples <- sub("^[^_]+_", "", original_names)
    samples <- sub("_raw$", "", samples)

    # Verifica i duplicati
    duplicate_count <- sum(duplicated(raw_barcodes))
    if (duplicate_count > 0) {
        log_warn(sprintf(
            "Found %d duplicated barcodes! Resolving using make.unique().",
            duplicate_count
        ))
    }

    # Rendi i barcode univoci per Seurat (es. AAAC, AAAC-1, AAAC-2)
    unique_barcodes <- make.unique(raw_barcodes, sep = "-")

    log_info("Creating b2sample mapping...")

    # Mantieni esattamente 2 colonne: il barcode (univoco) e il sample originale
    barcode_mapping <- data.frame(
        Barcode = unique_barcodes,
        Sample = samples,
        stringsAsFactors = FALSE
    )

    if (!is.null(output_dir)) {
        if (!dir.exists(output_dir)) {
            dir.create(output_dir, recursive = TRUE)
        }
        log_info("Saving b2sample...")
        tsv_path <- file.path(output_dir, file_name)
        utils::write.table(
            barcode_mapping,
            file = tsv_path,
            sep = "\t",
            row.names = FALSE,
            quote = FALSE
        )
    }

    log_info("Renaming cells in Seurat object...")
    seurat_renamed <- SeuratObject::RenameCells(seurat_obj, new.names = unique_barcodes)

    log_stat(sprintf("Total cells renamed: %d", length(original_names)))
    log_stat(sprintf("Duplicate barcodes resolved: %d", duplicate_count))
    log_header(is_complete = TRUE)

    return(seurat_renamed)
}#' Round Seurat Raw Counts to Integers
#'
#' Extracts the raw sparse matrix from a Seurat object, rounds all values to the
#' nearest integer, and replaces the assay data.
#'
#' @param seurat_obj A `Seurat` object.
#' @param assay Character. The assay to use. Default is "RNA".
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object.
#'   Default is `"seurat_rounded_counts.rds"`.
#'
#' @return A `Seurat` object with strictly integer counts.
#'
#' @importFrom Seurat GetAssayData SetAssayData
#' @importFrom Matrix drop0
#' @export
round_seurat_counts <- function(
  seurat_obj,
  assay = "RNA",
  output_dir = NULL,
  file_name = "seurat_rounded_counts.rds"
) {
  log_header("round seurat counts")

  log_info("Extracting counts from assay...")
  raw_matrix <- Seurat::GetAssayData(seurat_obj, assay = assay, layer = "counts")

  log_info("Rounding decimal values to integers...")
  raw_matrix@x <- round(raw_matrix@x)

  log_info("Dropping explicit zeros...")
  raw_matrix <- Matrix::drop0(raw_matrix)

  valid_cells <- .not_empty_droplets(raw_matrix)
  num_cells_before <- ncol(raw_matrix)
  cells_dropped <- num_cells_before - sum(valid_cells)

  log_info("Updating Seurat object with rounded counts...")
  seurat_obj <- Seurat::SetAssayData(
    seurat_obj,
    layer = "counts",
    new.data = raw_matrix,
    assay = assay
  )

  seurat_filtered <- seurat_obj
  if (cells_dropped > 0) {
    log_info("Removing cells that became completely empty after rounding...")
    seurat_filtered <- seurat_obj[, valid_cells]
  }

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  log_stat(sprintf("Assay: '%s'", assay))
  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
#' Filter Seurat Object to Remove Empty Droplets
#'
#' Filters out cells from a Seurat object that have zero RNA counts, effectively removing empty
#' droplets from the dataset.
#'
#' @param seurat_obj A `Seurat` object containing single-cell RNA-seq data.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object.
#'   Default is `"seurat_no_empty_droplets.rds"`.
#'
#' @return A new `Seurat` object with empty droplets removed.
#'
#' @importFrom Seurat GetAssayData
#' @export
filter_empty_droplets <- function(
  seurat_obj,
  output_dir = NULL,
  file_name = "seurat_no_empty_droplets.rds"
) {
  log_header("filter empty droplets")

  counts_mat <- Seurat::GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

  log_info("Identifying non-empty droplets...")
  valid_cells <- .not_empty_droplets(counts_mat)

  # Fast Subsetting
  log_info("Subsetting Seurat object...")
  seurat_filtered <- seurat_obj[, valid_cells]

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
#' Filter Seurat Object to Retain Only Spliced Transcripts
#'
#' Filters the features of a Seurat object to keep only those that match a specific
#' prefix.
#'
#' @param seurat_obj A `Seurat` object.
#' @param prefix Character string. The regex prefix to match spliced transcripts. Default is "^ENST".
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object.
#'                  Default is `"seurat_spliced_filtered.rds"`.
#'
#' @return A new, filtered `Seurat` object containing only the matched features.
#'
#' @importFrom SeuratObject Features
#' @export
filter_spliced_transcripts <- function(
  seurat_obj,
  prefix = "^ENST",
  output_dir = NULL,
  file_name = "seurat_spliced_filtered.rds"
) {
  log_header("filter spliced transcripts")
  log_info("Filtering features by prefix...")

  all_features <- SeuratObject::Features(seurat_obj)
  spliced_features <- grep(prefix, all_features, value = TRUE, perl = TRUE)
  num_features_after <- length(spliced_features)

  if (num_features_after == 0) {
    log_error("No features match the provided prefix. Check your matrix row names.", stop_exec = FALSE)
  }

  num_features_before <- length(all_features)
  if (num_features_after < (num_features_before * 0.05)) {
    log_warn(sprintf(
      "Extreme filtering detected. Less than 5%% of features retained. Is the prefix '%s' correct?", prefix
    ))
  }

  log_info("Checking for cells that became empty due to feature removal...")
  valid_cells <- .find_non_empty_cells(seurat_obj, spliced_features)

  num_cells_before <- ncol(seurat_obj)
  cells_dropped <- num_cells_before - sum(valid_cells)

  if (cells_dropped > 0) {
    log_info("Removing empty cells...")
    seurat_filtered <- seurat_obj[spliced_features, valid_cells]
  } else {
    seurat_filtered <- seurat_obj[spliced_features, ]
  }

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  log_stat(sprintf("Filter prefix: '%s'", prefix))
  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
#' Filter Seurat Object by Mitochondrial Transcript Percentage
#'
#' Calculates the percentage of mitochondrial counts per cell using a custom
#' list of transcript IDs and filters out cells exceeding a specified threshold.
#'
#' @param seurat_obj A `Seurat` object containing single-cell RNA-seq data.
#' @param mt_transcripts_list A character vector containing transcript IDs.
#' @param threshold Numeric. Maximum acceptable MT percentage. Default is 5.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"seurat_mt_filtered.rds"`.
#'
#' @return A new, filtered `Seurat` object. It has an additional metadata column `percent.mt`
#' representing the percentage of mitochondrial counts per cell.
#'
#' @importFrom Seurat PercentageFeatureSet
#' @importFrom SeuratObject Features
#' @export
filter_mt_transcripts <- function(
  seurat_obj,
  mt_transcripts_list,
  threshold = 5,
  output_dir = NULL,
  file_name = "seurat_mt_filtered.rds"
) {
  log_header("filter mt transcripts")


  valid_mt <- base::intersect(mt_transcripts_list, SeuratObject::Features(seurat_obj))

  if (length(valid_mt) == 0) {
    log_error("No mitochondrial transcripts found in the matrix. Check that the ID format matches the Seurat rownames.",
      stop_exec = TRUE
    )
  }

  log_info("Filtering cells by mitochondrial transcript percentage...")

  seurat_obj[["percent.mt"]] <- Seurat::PercentageFeatureSet(
    seurat_obj,
    features = valid_mt,
    assay = "RNA"
  )

  # Optimized bracket notation instead of subset()
  seurat_filtered <- seurat_obj[, seurat_obj$percent.mt < threshold]

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  log_stat(sprintf("Valid mitochondrial transcripts: %d", length(valid_mt)))
  log_stat(sprintf("Mitochondrial threshold: %s%%", as.character(threshold)))
  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
#' Iteratively Filter Sparse Matrix in Seurat Object
#'
#' Extracts the raw sparse matrix from a Seurat object and iteratively applies
#' cutoffs for minimum expressing cells per gene and minimum expressed genes per cell.
#' It loops on the dgCMatrix until convergence (zero features or cells dropped).
#'
#' @param seurat_obj A `Seurat` object.
#' @param cells_cutoff Numeric. Fraction of cells a feature must be expressed in. Default is 0.003.
#' @param genes_cutoff Numeric. Fraction of features a cell must express. Default is 0.002.
#' @param loss_threshold Numeric. Threshold (0-1) to trigger a warning for data loss. Default is 0.5 (50%).
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object.
#'   Default is `"seurat_sparsity_filtered.rds"`.
#'
#' @return A new, subsetted `Seurat` object with the converged dimensions.
#'
#' @importFrom Seurat GetAssayData
#' @importFrom Matrix drop0
#' @export
filter_iterative_sparsity <- function(
  seurat_obj,
  cells_cutoff = 0.003,
  genes_cutoff = 0.002,
  loss_threshold = 0.5,
  output_dir = NULL,
  file_name = "seurat_sparsity_filtered.rds"
) {
  log_header("filter iterative sparsity")

  raw_mat <- Seurat::GetAssayData(seurat_obj, assay = "RNA", layer = "counts")
  raw_mat <- Matrix::drop0(raw_mat)

  initial_features <- nrow(raw_mat)
  initial_cells <- ncol(raw_mat)

  converged <- FALSE
  iteration <- 1

  while (!converged) {
    log_info("Running sparsity filter iteration...")
    start_genes <- nrow(raw_mat)
    start_cells <- ncol(raw_mat)

    # Filter genes
    absolute_gene_cutoff <- round(start_cells * cells_cutoff, digits = 0L)
    expressing_cells <- tabulate(raw_mat@i + 1L, nbins = start_genes)
    raw_mat <- raw_mat[expressing_cells > absolute_gene_cutoff, , drop = FALSE]

    # Filter cells
    absolute_cell_cutoff <- round(nrow(raw_mat) * genes_cutoff, digits = 0L)
    expressed_genes <- diff(raw_mat@p)
    raw_mat <- raw_mat[, expressed_genes > absolute_cell_cutoff, drop = FALSE]

    end_genes <- nrow(raw_mat)
    end_cells <- ncol(raw_mat)

    if (end_genes == 0 || end_cells == 0) {
      log_error(
        "Iterative filtering removed ALL cells or ALL features. Reduce the cells_cutoff or genes_cutoff values.",
        stop_exec = TRUE
      )
    }

    log_info("Completed sparsity filter iteration.")

    if ((start_genes - end_genes) == 0 && (start_cells - end_cells) == 0) {
      converged <- TRUE
    } else {
      iteration <- iteration + 1
    }
  }

  final_features <- nrow(raw_mat)
  final_cells <- ncol(raw_mat)

  feature_loss_ratio <- (initial_features - final_features) / initial_features
  cell_loss_ratio <- (initial_cells - final_cells) / initial_cells

  if (feature_loss_ratio > loss_threshold) {
    log_warn(sprintf("High feature loss detected! Removed %.1f%% of total features.", feature_loss_ratio * 100))
  }

  if (cell_loss_ratio > loss_threshold) {
    log_warn(sprintf("High cell loss detected! Removed %.1f%% of total cells.", cell_loss_ratio * 100))
  }

  log_info("Iterative filtering converged.")

  valid_features <- rownames(raw_mat)
  valid_cells <- colnames(raw_mat)

  log_info("Updating Seurat object...")
  # Optimized bracket notation instead of subset()
  seurat_filtered <- seurat_obj[valid_features, valid_cells]

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  log_stat(sprintf("Cells cutoff fraction: %f", cells_cutoff))
  log_stat(sprintf("Genes cutoff fraction: %f", genes_cutoff))
  log_stat(sprintf("Total iterations run: %d", iteration))
  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
#' Create a Toy Subset of a Seurat Object
#'
#' Randomly subsets a Seurat object to a specified number of features and cells,
#' ensuring that no empty droplets (cells with 0 counts for the sampled features)
#' are created in the process.
#'
#' @param seurat_obj A `Seurat` object.
#' @param num_features Integer. Number of random features (transcripts) to retain. Default is 10000.
#' @param num_cells Integer. Number of random cells to retain. Default is 8000.
#' @param seed Integer. Random seed for reproducibility. Default is 42.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"seurat_test_subset.rds"`.
#'
#' @return A randomly subsetted `Seurat` object with no empty droplets.
#'
#' @importFrom SeuratObject Features Cells
#' @export
create_test_subset <- function(
  seurat_obj,
  num_features = 10000,
  num_cells = 8000,
  seed = 42,
  output_dir = NULL,
  file_name = "seurat_test_subset.rds"
) {
  log_header("create test subset")
  set.seed(seed)

  all_features <- SeuratObject::Features(seurat_obj)
  all_cells <- SeuratObject::Cells(seurat_obj)

  actual_features_to_keep <- min(num_features, length(all_features))

  log_info("Sampling random features...")
  sampled_features <- sample(all_features, actual_features_to_keep)

  log_info("Identifying non-empty cells for the sampled features...")
  valid_cells_logical <- .find_non_empty_cells(seurat_obj, sampled_features)
  valid_cells <- all_cells[valid_cells_logical]

  if (length(valid_cells) == 0) {
    log_error("Fatal: No cells have counts for the randomly sampled features. Try increasing num_features.",
      stop_exec = TRUE
    )
  }

  actual_cells_to_keep <- min(num_cells, length(valid_cells))

  if (actual_cells_to_keep < num_cells) {
    log_warn(sprintf("Only %d valid non-empty cells found (requested %d).", actual_cells_to_keep, num_cells))
  }

  log_info("Sampling random non-empty cells...")
  sampled_cells <- sample(valid_cells, actual_cells_to_keep)

  log_info("Subsetting Seurat object...")
  seurat_subset <- seurat_obj[sampled_features, sampled_cells]

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_subset, output_dir, file_name)
  }

  .log_seurat_change(seurat_obj, seurat_subset)

  log_header(is_complete = TRUE)

  return(seurat_subset)
}
