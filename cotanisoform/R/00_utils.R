#' Save an R Object to a Specific Directory
#'
#' A utility helper function to safely store R objects (such as
#' `COTAN` or `Seurat` instances) to disk as `.rds` files. It automatically
#' checks if the target directory exists and creates it recursively if necessary.
#'
#' @param obj The R object to be saved (e.g., a Seurat or COTAN object).
#' @param out_dir Character. The destination directory path.
#' @param file_name Character. The name of the file. It is highly recommended
#'   to include the `.rds` extension (e.g., `"cotan_filtered.rds"`).
#'
#' @return Invisible character string containing the absolute or relative
#'   full path to the saved file.
#'
#' @export
save_object <- function(obj, out_dir, file_name) {
    log_header("save object")
    if (!grepl("\\.rds$", file_name, ignore.case = TRUE)) {
        log_warn(sprintf("The file name '%s' does not end with '.rds'. Appending it automatically.", file_name))
        file_name <- paste0(file_name, ".rds")
    }

    if (!dir.exists(out_dir)) {
        log_warn(sprintf("Directory '%s' does not exist. Creating it recursively.", out_dir))
        dir.create(out_dir, recursive = TRUE)
    }

    full_path <- file.path(out_dir, file_name)

    log_stat(sprintf("Saving object at: %s", full_path))
    saveRDS(obj, file = full_path)
    log_header(is_complete = TRUE)

    return(invisible(full_path))
}

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
