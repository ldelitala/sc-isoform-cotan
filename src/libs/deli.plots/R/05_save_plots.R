#' Generate and Save COTAN QC and Clustering Plots
#'
#' @param cotan_obj A processed COTAN object.
#' @param out_dir The directory to save the PDF plots.
#' @param prefix A string prefix for the file names (e.g., "sample1").
#' @param genes A named list of genes to label in the GDI plot. Default is NULL.
#' @param condition A string corresponding to the condition/sample (used for the plot title). Default is "".
#' @param statType Type of statistic to use for GDI ("S" or "G"). Default is "S".
#' @param GDIThreshold The threshold level used in the uniformity check. Default is 1.43.
#' @param GDIIn Pre-calculated GDI dataframe to speed up the process. Default is NULL.
#'
#' @importFrom COTAN GDIPlot UMAPPlot getMetadataElement
#' @importFrom ggplot2 ggsave
#' @export
save_cotan_plots <- function(
  cotan_obj,
  out_dir,
  prefix = "cotan_analysis",
  genes = NULL,
  condition = "",
  statType = "S",
  GDIThreshold = 1.43,
  GDIIn = NULL
) {
    if (!dir.exists(out_dir)) {
        dir.create(out_dir, recursive = TRUE)
    }

    log_info("Generating GDI Plot...")

    # Use do.call to handle the potentially NULL 'genes' parameter smoothly
    plot_args <- list(
        objCOTAN = cotan_obj,
        condition = condition,
        statType = statType,
        GDIThreshold = GDIThreshold,
        GDIIn = GDIIn
    )
    if (!is.null(genes)) {
        plot_args$genes <- genes
    }

    gdi_plot <- do.call(GDIPlot, plot_args)

    ggsave(
        filename = file.path(out_dir, paste0(prefix, "_GDI_plot.pdf")),
        plot = gdi_plot,
        width = 8,
        height = 6
    )

    log_stat(sprintf("Plots saved successfully to: %s", out_dir))
}
