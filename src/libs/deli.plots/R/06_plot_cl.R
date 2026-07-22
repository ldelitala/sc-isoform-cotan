#' Plot and Save Clusterization Results
#'
#' @description
#' Generates UMAP plots, summary plots, and markers heatmaps for a clusterization in a COTAN object.
#' Optionally saves the plots to a specified directory.
#'
#' @param cotan_obj A `COTAN` object.
#' @param clusterization_name Character. The name of the clusterization (e.g., `"split"`, `"merged"`). Default is `"merged"`.
#' @param markers_list Named list of marker genes to plot on the heatmap. Default is `NULL`.
#' @param output_dir Character. Optional directory to save the plots as PDF files. Default is `NULL`.
#' @param prefix Character. Prefix for the saved plot filenames. Default is `"cotan_clustering"`.
#'
#' @return A list containing the generated ggplot objects: `umap`, `summary`, and `heatmap`.
#'
#' @importFrom COTAN cellsUMAPPlot clustersSummaryPlot clustersMarkersHeatmapPlot
#' @importFrom ggplot2 ggsave
#' @export
plot_clustering_results <- function(
  cotan_obj,
  clusterization_name = "merged",
  markers_list = NULL,
  output_dir = NULL,
  prefix = "cotan_clustering"
) {
    log_header("Generating Clustering Plots")

    plots_list <- list()

    # 1. UMAP Plot
    log_info("Generating cells UMAP plot...")
    log_cotan_execution("cellsUMAPPlot()")
    log_parameters(clName = clusterization_name)
    umap_res <- COTAN::cellsUMAPPlot(cotan_obj, clName = clusterization_name)
    log_cotan_execution("cellsUMAPPlot()", is_complete = TRUE)
    
    if (is.list(umap_res) && "plot" %in% names(umap_res)) {
        plots_list[["umap"]] <- umap_res[["plot"]]
    } else {
        plots_list[["umap"]] <- umap_res
    }

    # 2. Summary Plot
    log_info("Generating clusters summary plot...")
    log_cotan_execution("clustersSummaryPlot()")
    log_parameters(clName = clusterization_name)
    summary_res <- COTAN::clustersSummaryPlot(
        cotan_obj,
        clName = clusterization_name,
        plotTitle = sprintf("%s Summary", clusterization_name)
    )
    log_cotan_execution("clustersSummaryPlot()", is_complete = TRUE)
    plots_list[["summary"]] <- summary_res[["plot"]]

    # 3. Markers Heatmap (if markers_list is provided)
    if (!is.null(markers_list)) {
        log_info("Generating markers heatmap plot...")
        log_cotan_execution("clustersMarkersHeatmapPlot()")
        log_parameters(clName = clusterization_name)
        heatmap_res <- COTAN::clustersMarkersHeatmapPlot(
            cotan_obj,
            clName = clusterization_name,
            groupMarkers = markers_list
        )
        log_cotan_execution("clustersMarkersHeatmapPlot()", is_complete = TRUE)
        plots_list[["heatmap"]] <- heatmap_res[["heatmapPlot"]]
    }

    # Save to directory if output_dir is provided
    if (!is.null(output_dir)) {
        if (!dir.exists(output_dir)) {
            log_warn(sprintf("Directory '%s' does not exist. Creating it recursively.", output_dir))
            dir.create(output_dir, recursive = TRUE)
        }

        for (p_name in names(plots_list)) {
            p <- plots_list[[p_name]]
            if (!is.null(p) && inherits(p, "ggplot")) {
                file_path <- file.path(output_dir, sprintf("%s_%s.pdf", prefix, p_name))
                log_info(sprintf("Saving plot '%s' to: %s", p_name, file_path))
                ggplot2::ggsave(
                    filename = file_path,
                    plot = p,
                    width = 8,
                    height = 6
                )
            }
        }
    }

    log_header("Generating Plots Complete", is_complete = TRUE)

    return(plots_list)
}
