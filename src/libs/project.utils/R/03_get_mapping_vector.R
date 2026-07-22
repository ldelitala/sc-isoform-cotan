#' Get a Named Vector from a Two-Column TSV
#'
#' Reads a two-column TSV file (e.g., mapping barcodes to sample names or
#' cluster IDs) and converts it into a named vector. The first column is
#' used as names, and the second column as values.
#'
#' @param tsv_file Character. Path to the TSV file.
#' @param has_header Boolean. TRUE if the file has a header. Default is TRUE.
#'
#' @return A named vector.
#'
#' @importFrom utils read.table
#' @importFrom project.logger log_header log_info log_stat
#' @export
get_mapping_vector <- function(tsv_file, has_header = TRUE) {
    log_header("Get mapping vector")

    if (!file.exists(tsv_file)) {
        stop(sprintf("TSV file not found: %s", tsv_file))
    }

    log_info("Retrieving the data...")
    data <- utils::read.table(tsv_file, header = has_header, sep = "\t", stringsAsFactors = FALSE)

    if (ncol(data) < 2) {
        stop("The TSV file must contain at least two columns.")
    }

    log_info("Creating the vector...")
    out_vec <- data[[2]]
    names(out_vec) <- data[[1]]

    log_stat(sprintf("TSV file path: %s", tsv_file))
    log_header(is_complete = TRUE)

    return(out_vec)
}