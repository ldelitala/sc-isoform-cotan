
#' Get a Uniform Value Vector from a Barcode List
#'
#' Reads a TSV file containing a list of barcodes (first column) and assigns
#' a uniform value to all of them.
#'
#' @param tsv_file Character. Path to the TSV file.
#' @param value Any scalar value (e.g., character string for cell type). Defaults is TRUE.
#' @param has_header Boolean. TRUE if the file has a header. Default is FALSE.
#'
#' @return A named vector uniformly populated with `value` (or TRUE), named by the barcodes.
#'
#' @importFrom utils read.table
#' @importFrom project.logger log_header log_info log_stat
#' @export
get_uniform_vector <- function(tsv_file, value = TRUE, has_header = FALSE) {
    log_header("Get uniform vector")

    if (!file.exists(tsv_file)) {
        stop(sprintf("TSV file not found: %s", tsv_file))
    }

    log_info("Retrieving the data...")
    data <- utils::read.table(tsv_file, header = has_header, sep = "\t", stringsAsFactors = FALSE)

    if (nrow(data) == 0) {
        warning(sprintf("File %s is empty or badly formatted.", tsv_file))
        return(character(0))
    }

    log_info("Creating the vector...")
    barcodes <- data[[1]]
    n <- length(barcodes)

    out_vec <- rep(value, n)
    names(out_vec) <- barcodes

    log_stat(sprintf("TSV file path: %s", tsv_file))
    log_header(is_complete = TRUE)

    return(out_vec)
}
