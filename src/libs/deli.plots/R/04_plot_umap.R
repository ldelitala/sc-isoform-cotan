#' Plot and Save UMAP Clusters
#'
#' @param cotan_obj A `COTAN` object with clustering complete.
#' @param out_dir Directory to save the output PDF.
#'
#' @importFrom COTAN cellsUMAPPlot
#' @export
plot_and_save_umap <- function(cotan_obj, out_dir) {
    umap_plot <- cellsUMAPPlot(cotan_obj)

    pdf_path <- file.path(out_dir, "umap_clusters.pdf")
    pdf(pdf_path, width = 8, height = 6)
    print(umap_plot)
    dev.off()

    message(paste("Saved UMAP clusters plot to", pdf_path))
}
