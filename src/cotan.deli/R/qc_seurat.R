# Seurat QC and Filtering Module

#' Filter Seurat Object by Mitochondrial Transcript Percentage
#'
#' @description
#' Calculates the percentage of mitochondrial counts per cell using a custom
#' list of transcript IDs and filters out cells exceeding a specified threshold.
#'
#' @param seurat_obj A `Seurat` object containing single-cell RNA-seq data.
#' @param mt_transcripts_list A character vector containing transcript IDs.
#' @param threshold Numeric. Maximum acceptable MT percentage. Default is 5.
#'
#' @return A new, filtered `Seurat` object.
#'
#' @importFrom Seurat PercentageFeatureSet Features
#' @export
filter_mt_transcripts <- function(seurat_obj, mt_transcripts_list, threshold = 5) {
  log_header("Mitochondrial Filtering")

  log_info("Pre-filtering completely empty droplets...")
  seurat_obj <- subset(seurat_obj, subset = nCount_RNA > 0)

  valid_mt <- base::intersect(mt_transcripts_list, Features(seurat_obj))
  log_info(sprintf("Found %d valid mitochondrial transcripts.", length(valid_mt)))

  log_info(sprintf("Filtering cells with MT counts >= %s%%...", threshold))

  seurat_obj[["percent.mt"]] <- PercentageFeatureSet(
    seurat_obj,
    features = valid_mt,
    assay = "RNA"
  )

  num_cells_before <- ncol(seurat_obj)
  seurat_filtered <- subset(seurat_obj, subset = percent.mt < threshold)
  num_cells_after <- ncol(seurat_filtered)

  log_stat(sprintf("Cells before: %d", num_cells_before))
  log_stat(sprintf("Cells removed: %d", (num_cells_before - num_cells_after)))
  log_stat(sprintf("Cells remaining: %d", num_cells_after))

  log_header("Filtering Complete", is_complete = TRUE)

  return(seurat_filtered)
}

#' Filter Seurat Object to Retain Only Spliced Transcripts
#'
#' @description
#' Filters the features of a Seurat object to keep only those that match a specific
#' prefix. This is used to retain mature, spliced transcripts (e.g., "ENST")
#' and discard unspliced/intronic regions (e.g., "ENSG").
#'
#' @param seurat_obj A `Seurat` object.
#' @param prefix Character string. The regex prefix to match spliced transcripts. Default is "^ENST".
#'
#' @return A new, filtered `Seurat` object containing only the matched features.
#'
#' @importFrom Seurat Features
#' @export
filter_spliced_transcripts <- function(seurat_obj, prefix = "^ENST") {
  log_header("Transcript Type Filtering")

  all_features <- Features(seurat_obj)
  num_features_before <- length(all_features)

  log_info(sprintf("Total features before filtering: %d", num_features_before))
  log_info(sprintf("Retaining only features matching prefix: '%s'...", prefix))

  spliced_features <- grep(prefix, all_features, value = TRUE)
  num_features_after <- length(spliced_features)

  if (num_features_after == 0) {
    log_error("No features match the provided prefix. Check your matrix row names.", stop_exec = TRUE)
  }

  seurat_filtered <- subset(seurat_obj, features = spliced_features)

  log_stat(sprintf("Features removed: %d", (num_features_before - num_features_after)))
  log_stat(sprintf("Features remaining: %d", num_features_after))

  log_header("Filtering Complete", is_complete = TRUE)

  return(seurat_filtered)
}

#' Create a Toy Subset of a Seurat Object
#'
#' @description
#' Randomly subsets a Seurat object to a specified number of features and cells.
#' This is useful for rapid testing, debugging, and sanity checks as suggested.
#'
#' @param seurat_obj A `Seurat` object.
#' @param num_features Integer. Number of random features (transcripts) to retain. Default is 10000.
#' @param num_cells Integer. Number of random cells to retain. Default is 8000.
#' @param seed Integer. Random seed for reproducibility. Default is 42.
#'
#' @return A randomly subsetted `Seurat` object.
#'
#' @importFrom Seurat Features Cells
#' @export
create_test_subset <- function(seurat_obj, num_features = 10000, num_cells = 8000, seed = 42) {
  log_header("Creating Test Subset")

  set.seed(seed)

  all_features <- Features(seurat_obj)
  all_cells <- Cells(seurat_obj)

  actual_features_to_keep <- min(num_features, length(all_features))
  actual_cells_to_keep <- min(num_cells, length(all_cells))

  log_info(sprintf("Sampling %d random features (out of %d)...", actual_features_to_keep, length(all_features)))
  sampled_features <- sample(all_features, actual_features_to_keep)

  log_info(sprintf("Sampling %d random cells (out of %d)...", actual_cells_to_keep, length(all_cells)))
  sampled_cells <- sample(all_cells, actual_cells_to_keep)

  log_info("Subsetting Seurat object...")
  seurat_subset <- subset(seurat_obj, features = sampled_features, cells = sampled_cells)

  log_stat(sprintf("Final matrix: %d cells, %d features", ncol(seurat_subset), nrow(seurat_subset)))

  log_header("Subset Complete", is_complete = TRUE)

  return(seurat_subset)
}

#' Iteratively Filter Sparse Matrix in Seurat Object
#'
#' @description
#' Extracts the raw sparse matrix from a Seurat object and iteratively applies
#' cutoffs for minimum expressing cells per gene and minimum expressed genes per cell.
#' It loops on the dgCMatrix until convergence (zero features or cells dropped),
#' permanently solving the "ghost" transcript problem before COTAN conversion.
#'
#' @param seurat_obj A `Seurat` object.
#' @param cells_cutoff Numeric. Fraction of cells a feature must be expressed in. Default is 0.003.
#' @param genes_cutoff Numeric. Fraction of features a cell must express. Default is 0.002.
#'
#' @return A new, subsetted `Seurat` object with the converged dimensions.
#'
#' @importFrom Seurat GetAssayData
#' @importFrom Matrix rowSums colSums
#' @export
filter_iterative_sparsity <- function(seurat_obj, cells_cutoff = 0.003, genes_cutoff = 0.002) {
  log_header("Iterative Sparsity Filtering")

  log_info("Extracting raw counts matrix...")
  raw_mat <- GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

  converged <- FALSE
  iteration <- 1

  while (!converged) {
    log_info(sprintf("Iteration %d...", iteration))

    start_genes <- nrow(raw_mat)
    start_cells <- ncol(raw_mat)

    # 1. Feature (Gene/Transcript) Filter
    cutoff_g <- round(start_cells * cells_cutoff, digits = 0L)
    expressing_cells <- Matrix::rowSums(raw_mat > 0)
    raw_mat <- raw_mat[expressing_cells > cutoff_g, , drop = FALSE]

    # 2. Cell Filter
    cutoff_c <- round(nrow(raw_mat) * genes_cutoff, digits = 0L)
    expressed_genes <- Matrix::colSums(raw_mat > 0)
    raw_mat <- raw_mat[, expressed_genes > cutoff_c, drop = FALSE]

    end_genes <- nrow(raw_mat)
    end_cells <- ncol(raw_mat)

    dropped_g <- start_genes - end_genes
    dropped_c <- start_cells - end_cells

    log_stat(sprintf("Dropped %d features and %d cells", dropped_g, dropped_c))

    if (dropped_g == 0 && dropped_c == 0) {
      converged <- TRUE
      log_info("Matrix converged! No ghosts remain.")
    } else {
      iteration <- iteration + 1
    }
  }

  log_info("Subsetting original Seurat object to match converged matrix...")
  valid_features <- rownames(raw_mat)
  valid_cells <- colnames(raw_mat)

  seurat_filtered <- subset(seurat_obj, features = valid_features, cells = valid_cells)

  log_stat(sprintf("Final dimensions: %d cells, %d features", ncol(seurat_filtered), nrow(seurat_filtered)))

  log_header("Filtering Complete", is_complete = TRUE)

  return(seurat_filtered)
}
