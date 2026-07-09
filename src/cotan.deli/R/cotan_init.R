
#' Initialize COTAN Object from Seurat Object
#'
#' @description
#' Converts a Seurat object into a COTAN object, ensuring counts are
#' properly rounded to integers and metadata is transferred safely.
#' Is thought to be used after mithocondrial filtering and before
#' cleaning the COTAN object. The seurat object must have a "percent.mt"
#' column in its metadata.
#'
#' @param seurat_obj A `Seurat` object.
#' @param geo_id String. Identifier for the experiment.
#' @param seq_method String. Sequencing method (Default "10XV1").
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

    log_info("Extracting raw counts from Seurat object...")
    raw_matrix <- GetAssayData(seurat_obj, assay = "RNA", layer = "counts")

    log_info("Rounding decimal values to integers...")
    raw_matrix@x <- round(raw_matrix@x)

    log_info("Creating COTAN object & base metadata...\n")

    log_cotan_execution("COTAN()")
    cotan_obj <- COTAN(raw = raw_matrix)
    log_cotan_execution("COTAN()", is_complete = TRUE)

    log_info("parameters for COTAN object:")
    log_stat(sprintf("GEO ID: %s", geo_id))
    log_stat(sprintf("Sequencing Method: %s", seq_method))
    log_stat(sprintf("Sample Condition: %s\n", condition))

    log_cotan_execution("initializeMetaDataset()")
    cotan_obj <- initializeMetaDataset(
      cotan_obj,
      GEO = geo_id,
      sequencingMethod = seq_method,
      sampleCondition = condition
    )
    log_cotan_execution("initializeMetaDataset()", is_complete = TRUE)

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

    names(cell_origins) <- cotan_cells

    origin_counts <- table(cell_origins)
    origin_summary <- paste(
      names(origin_counts),
      as.numeric(origin_counts),
      sep = ": ", collapse = " | "
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

    log_stat(sprintf("Origin Summary: [ %s ]\n", origin_summary))

    log_cotan_execution("addCondition()")
    cotan_obj <- addCondition(
      cotan_obj,
      condName = "origin",
      conditions = base::as.factor(cell_origins),
      override = override
    )
    log_cotan_execution("addCondition()", is_complete = TRUE)

    log_header("Initialization Complete", is_complete = TRUE)

    return(cotan_obj)
  }
