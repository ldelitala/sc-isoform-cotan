#' Plot and Save Cleaned COTAN Plots
#'
#' @description
#' Generates diagnostic plots for a cleaned COTAN object using the `cleanPlots` function.
#' These plots include PCA of cells, cells' UDE against PCA, and nu plots.
#' It can optionally save these plots to a specified directory.
#'
#' @param cotan_obj A cleaned `COTAN` object.
#' @param output_dir Character. Optional directory to save the plots as PDF files. Default is `NULL`.
#' @param prefix Character. Prefix for the saved plot filenames. Default is `"cotan_clean"`.
#' @param include_pca Boolean. Whether to calculate the PCA associated with the normalized matrix. Default is `TRUE`.
#'
#' @return A list of plots/data returned by `cleanPlots`.
#'
#' @importFrom COTAN cleanPlots
#' @importFrom ggplot2 ggsave
#' @import project.base
#' @import project.logger
#' @import deli.cotan.core
#' @export
plot_cleaned_cotan <- function(
  cotan_obj,
  output_dir = NULL,
  prefix = "cotan_clean",
  include_pca = TRUE
) {
  log_header("Generating Cleaned COTAN Plots")

  log_cotan_execution("cleanPlots()")
  log_parameters(includePCA = include_pca)
  cl_plots <- COTAN::cleanPlots(cotan_obj, includePCA = include_pca)
  log_cotan_execution("cleanPlots()", is_complete = TRUE)

  if (!is.null(output_dir)) {
    if (!dir.exists(output_dir)) {
      log_warn(sprintf("Directory '%s' does not exist. Creating it recursively.", output_dir))
      dir.create(output_dir, recursive = TRUE)
    }

    for (p_name in names(cl_plots)) {
      p <- cl_plots[[p_name]]
      if (inherits(p, "ggplot")) {
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

  return(cl_plots)
}
