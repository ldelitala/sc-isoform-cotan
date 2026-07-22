#' Plot GDI Mixture Sensitivity
#'
#' @description
#' Recreates the GDI sensitivity plot from the COTAN paper (e.g. Figure 4),
#' showing how the GDI tail statistics change as a function of the cell type mixing ratio.
#'
#' @param simulation_results A named list of GDI data frames or vectors, keyed by mixing ratio.
#'                           Each GDI object must contain a "GDI" column/value.
#' @param out_dir Character. Directory to save the output plot.
#' @param gdi_threshold Numeric. GDI threshold to assess (e.g. 1.4 or 1.43). Default is 1.43.
#' @param file_prefix Character. Prefix for the saved files. Default is `"gdi_sensitivity"`.
#'
#' @return Invisible list of generated ggplot objects.
#'
#' @importFrom ggplot2 ggplot aes geom_line geom_point theme_minimal labs ggsave geom_hline
#' @import project.base
#' @import project.logger
#' @export
plot_gdi_mixture_sensitivity <- function(
  simulation_results,
  out_dir,
  gdi_threshold = 1.43,
  file_prefix = "gdi_sensitivity"
) {
    log_header("Plotting GDI Mixture Sensitivity")

    if (!dir.exists(out_dir)) {
        log_info(sprintf("Creating output directory: %s", out_dir))
        dir.create(out_dir, recursive = TRUE)
    }

    # Compile GDI stats for each ratio
    ratios <- as.numeric(names(simulation_results))
    plot_data <- data.frame()

    for (ratio_str in names(simulation_results)) {
        ratio_val <- as.numeric(ratio_str)
        gdi_obj <- simulation_results[[ratio_str]]

        # Handle different structures of getGDI output (could be vector or dataframe)
        if (is.data.frame(gdi_obj) && "GDI" %in% colnames(gdi_obj)) {
            gdi_values <- gdi_obj$GDI
        } else if (is.data.frame(gdi_obj)) {
            gdi_values <- gdi_obj[[1]]
        } else {
            gdi_values <- as.numeric(gdi_obj)
        }

        # Calculate metrics
        p99 <- quantile(gdi_values, 0.99, na.rm = TRUE)
        p95 <- quantile(gdi_values, 0.95, na.rm = TRUE)
        frac_exceeding <- mean(gdi_values > gdi_threshold, na.rm = TRUE)

        plot_data <- rbind(plot_data, data.frame(
            Ratio = ratio_val,
            Percentile99 = p99,
            Percentile95 = p95,
            FracExceeding = frac_exceeding
        ))
    }

    # Sort by ratio
    plot_data <- plot_data[order(plot_data$Ratio), ]

    log_info("GDI sensitivity metrics computed:")
    for (i in 1:nrow(plot_data)) {
        log_stat(sprintf(
            "  Ratio: %4.2f | 99th Pct GDI: %5.3f | Fraction > %s: %5.3f%%",
            plot_data$Ratio[i],
            plot_data$Percentile99[i],
            format(gdi_threshold),
            plot_data$FracExceeding[i] * 100
        ))
    }

    # 1. Plot 99th & 95th Percentile GDI
    p_pct <- ggplot2::ggplot(plot_data, ggplot2::aes(x = Ratio)) +
        ggplot2::geom_line(ggplot2::aes(y = Percentile99, color = "99th Percentile"), size = 1) +
        ggplot2::geom_point(ggplot2::aes(y = Percentile99, color = "99th Percentile"), size = 3) +
        ggplot2::geom_line(ggplot2::aes(y = Percentile95, color = "95th Percentile"), size = 1, linetype = "dashed") +
        ggplot2::geom_point(ggplot2::aes(y = Percentile95, color = "95th Percentile"), size = 3) +
        ggplot2::geom_hline(yintercept = gdi_threshold, color = "red", linetype = "dotted", size = 1) +
        ggplot2::theme_minimal() +
        ggplot2::labs(
            title = "GDI Percentiles vs Mixture Ratio",
            subtitle = "Dotted line represents the GDI Uniformity threshold",
            x = "Mixing Ratio (Cell Type A / Total)",
            y = "GDI Score",
            color = "Metric"
        )

    # 2. Plot Fraction of Genes Exceeding Threshold
    p_frac <- ggplot2::ggplot(plot_data, ggplot2::aes(x = Ratio, y = FracExceeding * 100)) +
        ggplot2::geom_line(color = "darkblue", size = 1) +
        ggplot2::geom_point(color = "darkblue", size = 3) +
        ggplot2::theme_minimal() +
        ggplot2::labs(
            title = sprintf("%% Genes Exceeding GDI Threshold (%s)", format(gdi_threshold)),
            x = "Mixing Ratio (Cell Type A / Total)",
            y = "% of Genes",
            caption = "Higher percentage indicates higher transcriptomic heterogeneity"
        )

    # Save plots
    pct_path <- file.path(out_dir, paste0(file_prefix, "_percentiles.pdf"))
    frac_path <- file.path(out_dir, paste0(file_prefix, "_exceeding_fraction.pdf"))

    ggplot2::ggsave(pct_path, plot = p_pct, width = 8, height = 6)
    ggplot2::ggsave(frac_path, plot = p_frac, width = 8, height = 6)

    log_info(sprintf("Saved percentile plot to: %s", pct_path))
    log_info(sprintf("Saved fraction plot to: %s", frac_path))
    log_header("Plotting Complete", is_complete = TRUE)

    return(invisible(list(plot_percentiles = p_pct, plot_fraction = p_frac)))
}
