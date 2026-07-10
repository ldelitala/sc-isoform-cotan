#' Initialize COTAN Object from Seurat Object
#'
#' @description
#' Converts a Seurat object into a COTAN object, ensuring metadata is
#' transferred safely. The Seurat object must have strictly integer counts
#' and a "percent.mt" column in its metadata.
#'
#' @param seurat_obj A `Seurat` object.
#' @param geo_id String. Identifier for the experiment.
#' @param seq_method String. Sequencing method.
#' @param condition String. Sample condition.
#' @param override Boolean. Silently allows overriding data for an existing condition name. Default is FALSE.
#'
#' @return An initialized `COTAN` object.
#'
#' @importFrom Seurat GetAssayData Cells
#' @importFrom COTAN COTAN initializeMetaDataset addCondition getCells getMetadataCells setColumnInDF
#' @export
initialize_cotan_from_seurat <-
  function(seurat_obj,
           geo_id,
           seq_method,
           condition,
           override = FALSE) {
    log_header("COTAN Initialization")

    if (!"percent.mt" %in% colnames(seurat_obj@meta.data)) {
      log_error("The 'percent.mt' column is missing from the Seurat object metadata. Cannot proceed.",
        stop_exec = TRUE
      )
    }

    raw_matrix <- GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

    log_info("Checking for non-integer values in counts...")
    if (any(raw_matrix@x %% 1 != 0)) {
      log_error(
        "The count matrix contains decimal values. Run 'round_seurat_counts()' before initializing COTAN.",
        stop_exec = TRUE
      )
    }

    log_info("Creating COTAN object & base metadata...")

    log_cotan_execution("COTAN()")
    cotan_obj <- COTAN(raw = raw_matrix)
    log_cotan_execution("COTAN()", is_complete = TRUE)

    log_cotan_execution(sprintf("initializeMetaDataset(%s, %s, %s)", geo_id, seq_method, condition))
    cotan_obj <- initializeMetaDataset(
      cotan_obj,
      GEO = geo_id,
      sequencingMethod = seq_method,
      sampleCondition = condition
    )
    log_cotan_execution(sprintf("initializeMetaDataset(%s, %s, %s)", geo_id, seq_method, condition), is_complete = TRUE)

    log_info("Transferring metadata (percent.mt)...")
    cotan_cells <- getCells(cotan_obj)
    matched_indices <- match(cotan_cells, Cells(seurat_obj))

    if (any(is.na(matched_indices))) {
      log_warn("Discrepancy detected between COTAN and Seurat cells.")
    }

    cotan_obj@metaCells <-
      setColumnInDF(
        df = getMetadataCells(cotan_obj),
        colToSet = seurat_obj$percent.mt[matched_indices],
        colName = "percent.mt",
        rowNames = cotan_cells
      )

    log_info("Extracting cell origins from barcodes...")
    cell_origins <- sapply(
      strsplit(cotan_cells, "_"),
      function(x) {
        if (length(x) >= 3) {
          x[3]
        } else {
          "Unknown"
        }
      }
    )

    num_unknown <- sum(cell_origins == "Unknown")

    if (num_unknown > 0) {
      log_warn(sprintf("%d cells have irregular barcode formats (set to 'Unknown').", num_unknown))

      weird_cells <- cotan_cells[cell_origins == "Unknown"]
      weird_sample <- paste(utils::head(weird_cells, 10), collapse = ", ")
      log_stat(sprintf("Preview: %s", weird_sample))
    } else {
      log_stat("Diagnostic: All barcodes formatted correctly.")
    }

    names(cell_origins) <- cotan_cells

    origin_counts <- table(cell_origins)

    for (i in seq_along(origin_counts)) {
      log_stat(sprintf(
        "Origin Summary: %s: %d",
        names(origin_counts)[i],
        as.numeric(origin_counts)[i]
      ))
    }

    log_cotan_execution(sprintf("addCondition(override = %s)", override))
    cotan_obj <- addCondition(
      cotan_obj,
      condName = "origin",
      conditions = base::as.factor(cell_origins),
      override = override
    )
    log_cotan_execution(sprintf("addCondition(override = %s)", override), is_complete = TRUE)

    log_header("Initialization Complete", is_complete = TRUE)

    return(cotan_obj)
  }

#' Clean COTAN Object
#'
#' @description
#' Applies the basic COTAN clean() method to remove sparse genes and cells.
#' It finds fully-expressed genes and fully-expressing cells,
#' returns the given COTAN object with updated fully-expressed genes' information
#' Mitochondrial filtering is assumed to be handled prior to this step.
#'
#' @param cotan_obj A `COTAN` object.
#' @param cells_cutoff Numeric. Fraction of cells a gene must be expressed in to be kept (Default 0.003).
#' @param genes_cutoff Numeric. Fraction of genes a cell must express to be kept (Default 0.002).
#' @param cells_threshold Numeric. Genes expressed in > fraction of cells marked as fully-expressed (Default 0.99).
#' @param genes_threshold Numeric. Cells expressing > fraction of genes marked as fully-expressing (Default 0.99).
#'
#' @return A cleaned `COTAN` object with updated `nu` estimators.
#'
#' @importFrom COTAN clean getNumCells getNumGenes
#' @export
clean_cotan_data <-
  function(cotan_obj,
           cells_cutoff = 0.003,
           genes_cutoff = 0.002,
           cells_threshold = 0.99,
           genes_threshold = 0.99) {
    log_header("COTAN Cleaning")

    log_stat(sprintf("Cells cutoff: %f", cells_cutoff))
    log_stat(sprintf("Genes cutoff: %f", genes_cutoff))
    log_stat(sprintf("Cells threshold: %f", cells_threshold))
    log_stat(sprintf("Genes threshold: %f", genes_threshold))

    num_cells_before <- getNumCells(cotan_obj)
    num_genes_before <- getNumGenes(cotan_obj)

    log_stat(sprintf("Initial Cells: %d", num_cells_before))
    log_stat(sprintf("Initial Genes: %d", num_genes_before))

    log_cotan_execution("clean()")
    cotan_obj <- clean(
      cotan_obj,
      cellsCutoff = cells_cutoff,
      genesCutoff = genes_cutoff,
      cellsThreshold = cells_threshold,
      genesThreshold = genes_threshold
    )
    log_cotan_execution("clean()", is_complete = TRUE)

    num_cells_after <- getNumCells(cotan_obj)
    num_genes_after <- getNumGenes(cotan_obj)

    if (num_cells_after == 0 || num_genes_after == 0) {
      log_error("The clean() method removed ALL cells or ALL genes. Check your cutoff parameters.", stop_exec = TRUE)
    }

    if (num_cells_after < (num_cells_before * 0.2)) {
      log_warn("Warning: cleaning removed over 80% of the cells. The parameters might be too restrictive.")
    }

    log_stat(sprintf("Final Cells: %d", num_cells_after))
    log_stat(sprintf("Final Genes: %d", num_genes_after))

    log_stat(sprintf("Cells Removed: %d", (num_cells_before - num_cells_after)))
    log_stat(sprintf("Genes Removed: %d", (num_genes_before - num_genes_after)))

    log_header("Cleaning Complete", is_complete = TRUE)

    return(cotan_obj)
  }
