#' Map transcripts to genes using a t2g file
#'
#' @param cotan_obj A COTAN object (transcript-level).
#' @param t2g_file Character. Path to the t2g mapping file.
#' @param has_header Boolean. TRUE if the file has a header. Default is FALSE.
#' @param col_name Character. The name of the new column in metaGenes. Default is "gene_id".
#' @return The updated COTAN object.
#'
#' @export
add_gene_info_from_t2g <- function(cotan_obj, t2g_file, has_header = FALSE, col_name = "gene_id") {
    log_header("ADD GENE INFO FROM T2G")

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
    log_header("ADDING ORIGIN GENE METADATA complete", is_complete = TRUE)

    return(cotan_obj)
}
