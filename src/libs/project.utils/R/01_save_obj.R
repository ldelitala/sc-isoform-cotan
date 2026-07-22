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
#' @importFrom project.logger log_header log_warn log_stat
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
