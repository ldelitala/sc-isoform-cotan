#' Run GDI Mixture Simulation
#'
#' @description
#' Simulates mixtures of two cell types at various proportions and runs the COTAN pipeline
#' to calculate the GDI for each mixture.
#'
#' @param cotan_obj A `COTAN` object.
#' @param cell_type_a Character. First cell type name (e.g. "T-cell").
#' @param cell_type_b Character. Second cell type name (e.g. "B-cell").
#' @param proportions Numeric vector. The mixing proportions of `cell_type_a` to test. Default: `c(0, 0.05, 0.1, 0.2, 0.4, 0.8)`.
#' @param num_cells Integer. Total number of cells to sample for each mixture. Default is `1000L`.
#' @param cond_name Character. Name of the cell type metadata condition. Default is `"cell_type"`.
#' @param seed Integer. Random seed for reproducibility. Default is `42`.
#' @param cores Integer. Number of cores for bisection dispersion estimation and GDI. Default is `1L`.
#' @param optimize_for_speed Logical. Use torch acceleration for COEX. Default is `TRUE`.
#' @param device_str Character. Device for torch calculations ("cpu", "cuda"). Default is `"cuda"`.
#'
#' @return A list of GDI vectors/data.frames for each tested proportion.
#'
#' @importFrom COTAN getMetadataCells getCells getGDI
#' @import project.base
#' @import project.logger
#' @import deli.cotan.core
#' @export
run_gdi_mixture_simulation <- function(
  cotan_obj,
  cell_type_a,
  cell_type_b,
  proportions = c(0, 0.05, 0.1, 0.2, 0.4, 0.8),
  num_cells = 1000L,
  cond_name = "cell_type",
  seed = 42,
  cores = 1L,
  optimize_for_speed = TRUE,
  device_str = "cuda"
) {
  log_header("Running GDI Mixture Simulation")
  set.seed(seed)

  metadata <- getMetadataCells(cotan_obj)
  if (!cond_name %in% colnames(metadata)) {
    log_error(sprintf("Metadata condition '%s' not found in COTAN object.", cond_name), stop_exec = TRUE)
  }

  cell_types <- metadata[[cond_name]]
  names(cell_types) <- getCells(cotan_obj)

  # Extract barcodes for each cell type
  barcodes_a <- names(cell_types)[cell_types == cell_type_a]
  barcodes_b <- names(cell_types)[cell_types == cell_type_b]

  log_info(sprintf("Cell Type A ('%s') available cells: %d", cell_type_a, length(barcodes_a)))
  log_info(sprintf("Cell Type B ('%s') available cells: %d", cell_type_b, length(barcodes_b)))

  if (length(barcodes_a) == 0 || length(barcodes_b) == 0) {
    log_error("One or both cell types have no cells in the metadata.", stop_exec = TRUE)
  }

  results <- list()

  for (prop in proportions) {
    log_header(sprintf("Simulation Mixture: %s%% of '%s'", format(prop * 100), cell_type_a))

    num_a <- round(prop * num_cells)
    num_b <- num_cells - num_a

    if (num_a > length(barcodes_a)) {
      log_warn(sprintf("Requested %d cells of type A, but only %d available. Sampling with replacement.", num_a, length(barcodes_a)))
      sampled_a <- sample(barcodes_a, num_a, replace = TRUE)
    } else {
      sampled_a <- sample(barcodes_a, num_a, replace = FALSE)
    }

    if (num_b > length(barcodes_b)) {
      log_warn(sprintf("Requested %d cells of type B, but only %d available. Sampling with replacement.", num_b, length(barcodes_b)))
      sampled_b <- sample(barcodes_b, num_b, replace = TRUE)
    } else {
      sampled_b <- sample(barcodes_b, num_b, replace = FALSE)
    }

    mixed_cells <- c(sampled_a, sampled_b)
    log_info(sprintf("Sampled %d cells (Type A: %d, Type B: %d)", length(mixed_cells), num_a, num_b))

    # Subset the COTAN object using the helper
    mixed_cotan <- subset_cotan_by_cells(cotan_obj, mixed_cells)

    # Run calibration and cleaning pipeline
    mixed_cotan <- clean_cotan_data(mixed_cotan)
    mixed_cotan <- prepare_to_coex(mixed_cotan, cores = cores)
    mixed_cotan <- calculate_coex(
      mixed_cotan,
      optimize_for_speed = optimize_for_speed,
      device_str = device_str
    )

    # Compute GDI
    mixed_cotan <- calculate_gdi(mixed_cotan, cores = cores)

    # Extract GDI data
    gdi_df <- getGDI(mixed_cotan)

    results[[as.character(prop)]] <- gdi_df
  }

  log_header("GDI Mixture Simulation Complete", is_complete = TRUE)
  return(results)
}
