#' Clean simpleaf Cell Names and Export Barcode Mapping
#'
#' @description
#' Standardizes cell names in a Seurat object generated from simpleaf in nf-core/scrnaseq by
#' removing the sample suffix (e.g., keeping only the barcode sequence).
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
    log_header("Cleaning simpleaf barcodes")

    original_names <- SeuratObject::Cells(seurat_obj)
    
    log_info("Processing cell names...")

    clean_barcodes <- sub("_.*", "", original_names)

    samples <- sub("^[^_]+_", "", original_names)
    samples <- sub("_raw$", "", samples)

    duplicate_count <- sum(duplicated(clean_barcodes))
    if (duplicate_count > 0) {
        log_warn(sprintf(
            "Found %d duplicated barcodes! Seurat 'RenameCells' may fail. Check input data.",
            duplicate_count
        ))
    }

    log_info("Creating b2sample mapping...")
    barcode_mapping <- data.frame(
        Barcode = clean_barcodes,
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
    seurat_renamed <- SeuratObject::RenameCells(seurat_obj, new.names = clean_barcodes)

    log_stat(sprintf("Cells: %d", length(original_names)))
    log_header("Cleaning simpleaf barcodes", is_complete = TRUE)
    return(seurat_renamed)
}
