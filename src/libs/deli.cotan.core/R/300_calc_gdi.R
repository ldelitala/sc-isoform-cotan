#' Calculate and Store GDI for a COTAN Object
#'
#' @description
#' Computes the Global Differential Expression Index (GDI), stores it, and saves the object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param cores Integer. Number of cores to use for parallel execution. Default is `1L`.
#' @param stat_type Character string. The type of statistic to use for GDI calculation ("S" or "G"). Default is "S".
#' @param rows_fraction Numeric. Fraction of rows to use for chunking in GDI. Default is 0.05.
#' @param chunk_size Integer. Size of the data chunks for GDI calculation. Default is 1024L.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"cotan_gdi.rds"`.
#'
#' @return An updated `COTAN` object containing the calculated GDI metrics.
#'
#' @importFrom COTAN calculateGDI storeGDI
#' @export
calculate_gdi <- function(
  cotan_obj,
  cores = 1L,
  stat_type = "S",
  rows_fraction = 0.05,
  chunk_size = 1024L,
  output_dir = NULL,
  file_name = "cotan_gdi.rds"
) {
    log_header("Computing Global Differential Expression Index (GDI)")
    log_cotan_execution("calculateGDI()")
    log_parameters(statType = stat_type, rowsFraction = rows_fraction, cores = cores, chunkSize = chunk_size)

    cotan_obj <- storeGDI(
        cotan_obj,
        genesGDI = calculateGDI(
            cotan_obj,
            statType = stat_type,
            rowsFraction = rows_fraction,
            cores = cores,
            chunkSize = chunk_size
        )
    )

    log_cotan_execution("calculateGDI()", is_complete = TRUE)

    if (!is.null(output_dir)) {
        save_object(cotan_obj, output_dir, file_name)
    }

    log_header("Calculation Complete", is_complete = TRUE)

    return(cotan_obj)
}
