#' Plot and Save GDI Distribution
#'
#' @description
#' Generates and saves the Global Differentiation Index (GDI) plot.
#' Automatically handles the mandatory 'genes' argument by sampling a specified
#' number of features if none are provided.
#'
#' @param cotan_obj A `COTAN` object.
#' @param out_dir Character. Directory to save the output PDF.
#' @param genes Named list. A list of genes to label, where each array will have a different color.
#'              Default is `NULL`.
#' @param sample_size Integer. Number of features to sample if `genes` is `NULL`. Default is `100L`.
#' @param condition Character. A string corresponding to the condition/sample (used only for the title).
#'                  Default is `""`.
#' @param stat_type Character. Type of statistic to be used ("S" for Pearson's chi-squared, "G" for G-test).
#'                  Default is `"S"`.
#' @param gdi_threshold Numeric. The threshold level used in a SimpleGDIUniformityCheck. Default is `1.43`.
#' @param gdi_in Data.frame. A pre-calculated GDI data frame to speed up the process. Default is `NULL`.
#'
#' @return Invisible character string containing the path to the saved PDF.
#'
#' @importFrom COTAN GDIPlot getGenes
#' @importFrom grDevices pdf dev.off
#' @export
plot_gdi <- function(
  cotan_obj,
  out_dir,
  genes = NULL,
  sample_size = 10L,
  condition = "",
  stat_type = "S",
  gdi_threshold = 1.43,
  gdi_in = NULL
) {
    log_header("Generating GDI Plot")

    if (is.null(genes)) {
        log_info(sprintf(
            "No genes list provided. Extracting a random sample of %d features for the plot...",
            sample_size
        ))

        actual_sample_size <- min(sample_size, COTAN::getNumGenes(cotan_obj))
        genes <- list("Sample" = sample(COTAN::getGenes(cotan_obj), actual_sample_size))
        log_stat(sprintf("Sampled %d features successfully.", actual_sample_size))
    }

    if (!dir.exists(out_dir)) {
        log_warn(sprintf("Output directory '%s' does not exist. Creating it now.", out_dir))
        dir.create(out_dir, recursive = TRUE)
    }

    log_cotan_execution("GDIPlot()")
    log_parameters(
        condition = condition,
        statType = stat_type,
        GDIThreshold = gdi_threshold,
        has_GDIIn = !is.null(gdi_in)
    )

    gdi_plot <- COTAN::GDIPlot(
        objCOTAN = cotan_obj,
        genes = genes,
        condition = condition,
        statType = stat_type,
        GDIThreshold = gdi_threshold,
        GDIIn = gdi_in
    )
    log_cotan_execution("GDIPlot()", is_complete = TRUE)

    log_info("Saving plot to disk...")

    pdf_path <- file.path(out_dir, "gdi_distribution.pdf")

    pdf(pdf_path, width = 8, height = 6)
    print(gdi_plot)
    dev.off()

    log_stat(sprintf("Status: GDI plot saved successfully to %s", pdf_path))

    log_header("Generating GDI Plot Complete", is_complete = TRUE)

    return(invisible(pdf_path))
}
