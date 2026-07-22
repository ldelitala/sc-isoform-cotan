#' Add a new column to the metaGenes data.frame
#'
#' @param cotan_obj A COTAN object.
#' @param col_name Character. The name of the new column to add.
#' @param col_data A named vector. The names must match the transcripts/genes in the object.
#' @return The updated COTAN object.
#'
#' @importFrom COTAN getMetadataGenes getGenes setColumnInDF
#' @import project.logger
#' @import project.utils
#' @export
add_genes_metadata <- function(cotan_obj, col_name, col_data) {
    log_header("add genes metadata")

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
    log_header(is_complete = TRUE)
    
    return(cotan_obj)
}

#' Map transcripts to genes using a t2g file
#'
#' @param cotan_obj A COTAN object (transcript-level).
#' @param t2g_file Character. Path to the t2g mapping file.
#' @param has_header Boolean. TRUE if the file has a header. Default is FALSE.
#' @param col_name Character. The name of the new column in metaGenes. Default is "gene_id".
#' @return The updated COTAN object.
#'
#' @import project.logger
#' @import project.utils
#' @export
add_gene_info_from_t2g <- function(cotan_obj, t2g_file, has_header = FALSE, col_name = "gene_id") {
    log_header("add gene info from t2g")

    if (is.null(t2g_file)) {
        log_error("Please provide a t2g.tsv file", stop_exec = TRUE)
    }

    log_info("Getting mapping vector...")
    gene_mapping <- get_mapping_vector(t2g_file, has_header = has_header)

    log_info("Adding genes metadata...")
    cotan_obj <- add_genes_metadata(
        cotan_obj = cotan_obj,
        col_name = col_name,
        col_data = gene_mapping
    )
    log_header(is_complete = TRUE)

    return(cotan_obj)
}
