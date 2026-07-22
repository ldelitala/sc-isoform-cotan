#' Add a new column to the metaGenes data.frame
#'
#' @param cotan_obj A COTAN object.
#' @param col_name Character. The name of the new column to add.
#' @param col_data A named vector. The names must match the transcripts/genes in the object.
#' @return The updated COTAN object.
#'
#' @importFrom COTAN getMetadataGenes getGenes setColumnInDF
#' @export
add_genes_metadata <- function(cotan_obj, col_name, col_data) {
    log_header("ADD GENES METADATA")

    all_transcripts <- COTAN::getGenes(cotan_obj)

    if (!is.null(names(col_data))) {
        log_info("Aligning data to transcripts...")
        aligned_data <- col_data[all_transcripts]

        num_nas <- sum(is.na(aligned_data))
        if (num_nas > 0) {
            log_warn(sprintf("Found %d missing values (NAs) after aligning data to transcripts.", num_nas))
        }
    } else {
        if (length(col_data) != length(all_transcripts)) {
            log_error(
                sprintf(
                    "Length mismatch: col_data has %d elements, but there are %d transcripts.",
                    length(col_data), length(all_transcripts)
                ),
                stop_exec = TRUE
            )
        }
        aligned_data <- col_data
    }

    log_info("Setting column in metadata dataframe...")
    log_cotan_execution("setColumnInDF()", colName = col_name)

    genes_metadata <- COTAN::setColumnInDF(
        df = COTAN::getMetadataGenes(cotan_obj),
        colToSet = aligned_data,
        colName = col_name,
        rowNames = all_transcripts
    )

    cotan_obj@metaGenes <- genes_metadata

    log_cotan_execution("setColumnInDF()", is_complete = TRUE)
    log_stat(sprintf("Transcripts targeted: %8s", format(length(all_transcripts), big.mark = ",", scientific = FALSE, trim = TRUE)))
    log_header("Metadata Update Completed", is_complete = TRUE)
    
    return(cotan_obj)
}