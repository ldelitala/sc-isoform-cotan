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
#' @importFrom project.logger log_header log_info log_warn log_stat
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
}