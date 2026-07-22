#' Plot and Save COEX Heatmap
#'
#' @description
#' Generates a COEX heatmap for selected genes list using the `heatmapPlot` function.
#' It can optionally save the heatmap to a specified directory.
#'
#' @param cotan_obj A `COTAN` object with a calculated COEX matrix.
#' @param genes_list A named list of genes (transcripts) to plot. Default is `NULL`.
#' @param sample_size Integer. Number of features to sample if `genes_list` is `NULL`. Default is `10L`.
#' @param output_dir Character. Optional directory to save the heatmap as a PDF file. Default is `NULL`.
#' @param prefix Character. Prefix for the saved plot filename. Default is `"cotan_coex"`.
#' @param p_value_threshold Numeric. The p-value threshold. Default is 0.01.
#' @param cores Integer. Number of cores to use. Default is 1L.
#'
#' @return A `ggplot2` object representing the heatmap.
#'
#' @importFrom COTAN heatmapPlot
#' @importFrom ggplot2 ggsave
#' @export
plot_coex_heatmap <- function(
  cotan_obj,
  genes_list = NULL,
  sample_size = 10L,
  output_dir = NULL,
  prefix = "cotan_coex",
  p_value_threshold = 0.01,
  cores = 1L
) {
    log_header("Generating COEX Heatmap")

    if (is.null(genes_list)) {
        log_info(sprintf(
            "No genes list provided. Extracting a random sample of %d features for the plot...",
            sample_size
        ))

        actual_sample_size <- min(sample_size, COTAN::getNumGenes(cotan_obj))
        genes_list <- list("Sample" = sample(COTAN::getGenes(cotan_obj), actual_sample_size))
        log_stat(sprintf("Sampled %d features successfully.", actual_sample_size))
    }

    log_cotan_execution("heatmapPlot()")
    log_parameters(pValueThreshold = p_value_threshold, cores = cores)
    
    coex_plot <- COTAN::heatmapPlot(
        objCOTAN = cotan_obj,
        genesLists = genes_list,
        pValueThreshold = p_value_threshold,
        cores = cores
    )
    log_cotan_execution("heatmapPlot()", is_complete = TRUE)

    if (!is.null(output_dir)) {
        if (!dir.exists(output_dir)) {
            log_warn(sprintf("Directory '%s' does not exist. Creating it recursively.", output_dir))
            dir.create(output_dir, recursive = TRUE)
        }

        file_path <- file.path(output_dir, sprintf("%s_heatmap.pdf", prefix))
        log_info(sprintf("Saving COEX heatmap to: %s", file_path))

        ggplot2::ggsave(
            filename = file_path,
            plot = coex_plot,
            width = 8,
            height = 6
        )
    }

    log_header("Generating Heatmap Complete", is_complete = TRUE)

    return(coex_plot)
}
