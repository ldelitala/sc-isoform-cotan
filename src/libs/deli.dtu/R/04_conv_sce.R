#' Convert COTAN Object to SingleCellExperiment
#'
#' @description
#' Wraps the COTAN object into a SingleCellExperiment object for downstream interoperability.
#'
#' @param cotan_obj A `COTAN` object.
#'
#' @return A `SingleCellExperiment` object.
#'
#' @importFrom COTAN convertToSingleCellExperiment
#' @export
convert_to_sce <- function(cotan_obj) {
    log_header("Converting to SingleCellExperiment")
    
    log_cotan_execution("convertToSingleCellExperiment()")
    sce_obj <- COTAN::convertToSingleCellExperiment(cotan_obj)
    log_cotan_execution("convertToSingleCellExperiment()", is_complete = TRUE)
    
    log_stat("Status: Conversion to SCE completed successfully.")
    log_header("Conversion Complete", is_complete = TRUE)
    
    return(sce_obj)
}
