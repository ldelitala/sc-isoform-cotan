#' Clean COTAN Object
#'
#' @description
#' Applies the basic COTAN clean() method to remove sparse genes and cells.
#' Mitochondrial filtering is assumed to be handled prior to this step.
#'
#' @param cotan_obj A `COTAN` object.
#' @param cells_cutoff Numeric. Fraction of cells a gene must be expressed in to be kept (Default 0.003).
#' @param genes_cutoff Numeric. Fraction of genes a cell must express to be kept (Default 0.002).
#' @param cells_threshold Numeric. Genes expressed in > fraction of cells marked as fully-expressed (Default 0.99).
#' @param genes_threshold Numeric. Cells expressing > fraction of genes marked as fully-expressing (Default 0.99).
#'
#' @return A cleaned `COTAN` object with updated `nu` estimators.
#'
#' @importFrom COTAN clean getNumCells getNumGenes
#' @export
clean_cotan_data <-
    function(cotan_obj,
             cells_cutoff = 0.003,
             genes_cutoff = 0.002,
             cells_threshold = 0.99,
             genes_threshold = 0.99) {
        log_header("COTAN Cleaning")

        log_info("Cleaning parameters:")
        log_stat(sprintf("Cells cutoff: %f", cells_cutoff))
        log_stat(sprintf("Genes cutoff: %f", genes_cutoff))
        log_stat(sprintf("Cells threshold: %f", cells_threshold))
        log_stat(sprintf("Genes threshold: %f\n", genes_threshold))

        num_cells_before <- getNumCells(cotan_obj)
        num_genes_before <- getNumGenes(cotan_obj)

        log_info("Initial matrix dimensions:")
        log_stat(sprintf("Cells: %d", num_cells_before))
        log_stat(sprintf("Genes: %d\n", num_genes_before))

        log_cotan_execution("clean()")
        cotan_obj <- clean(
            cotan_obj,
            cellsCutoff = cells_cutoff,
            genesCutoff = genes_cutoff,
            cellsThreshold = cells_threshold,
            genesThreshold = genes_threshold
        )
        log_cotan_execution("clean()", is_complete = TRUE)

        num_cells_after <- getNumCells(cotan_obj)
        num_genes_after <- getNumGenes(cotan_obj)

        log_info("Final matrix dimensions after cleaning:")
        log_stat(sprintf("Cells: %d", num_cells_after))
        log_stat(sprintf("Genes: %d\n", num_genes_after))

        log_info("Summary of removed elements:")
        log_stat(sprintf("Cells: %d", (num_cells_before - num_cells_after)))
        log_stat(sprintf("Genes: %d\n", (num_genes_before - num_genes_after)))

        log_header("Cleaning Complete", is_complete = TRUE)

        return(cotan_obj)
    }

#' Clean COTAN Object (Iterative + Dynamic Evaluation)
#'
#' @description
#' Applies an iterative cleaning method to remove sparse genes and cells.
#' It calculates expression sums dynamically directly from the raw matrix at each step 
#' to bypass COTAN's metadata cache, guaranteeing the complete removal of 0-count ghosts.
#'
#' @param cotan_obj A `COTAN` object.
#' @param cells_cutoff Numeric. Fraction of cells a gene must be expressed in to be kept.
#' @param genes_cutoff Numeric. Fraction of genes a cell must express to be kept.
#' @param cells_threshold Numeric. Genes expressed in > fraction of cells marked as fully-expressed.
#' @param genes_threshold Numeric. Cells expressing > fraction of genes marked as fully-expressing.
#'
#' @return A cleaned and stabilized `COTAN` object.
#'
#' @importFrom COTAN getRawData dropGenesCells findFullyExpressedGenes findFullyExpressingCells estimateNuLinear
#' @importFrom Matrix rowSums colSums
#' @export
clean_cotan_data_iterative <-
    function(cotan_obj,
             cells_cutoff = 0.003,
             genes_cutoff = 0.002,
             cells_threshold = 0.99,
             genes_threshold = 0.99) {
        log_header("COTAN Cleaning (Dynamic Iterative)")

        log_info("Cleaning parameters:")
        log_stat(sprintf("Cells cutoff: %f", cells_cutoff))
        log_stat(sprintf("Genes cutoff: %f\n", genes_cutoff))

        initial_cells <- ncol(getRawData(cotan_obj))
        initial_genes <- nrow(getRawData(cotan_obj))

        log_info("Initial matrix dimensions:")
        log_stat(sprintf("Cells: %d", initial_cells))
        log_stat(sprintf("Genes: %d\n", initial_genes))

        log_cotan_execution("Iterative dynamic filtering loop")
        
        converged <- FALSE
        iteration <- 1
        
        while (!converged) {
            log_info(sprintf("Iteration %d...", iteration))
            
            # Estraiamo la matrice attuale cruda per bypassare la cache
            raw_mat <- getRawData(cotan_obj)
            start_genes <- nrow(raw_mat)
            start_cells <- ncol(raw_mat)
            
            # 1. Filtro Geni (calcolato dinamicamente sulla matrice cruda)
            cutoff_g <- round(start_cells * cells_cutoff, digits = 0L)
            expressing_cells <- Matrix::rowSums(raw_mat > 0)
            genesToDrop <- rownames(raw_mat)[expressing_cells <= cutoff_g]
            
            if (length(genesToDrop) > 0) {
                cotan_obj <- dropGenesCells(cotan_obj, genes = genesToDrop)
            }
            
            # 2. Filtro Cellule (ri-estraiamo la matrice perché i geni sono cambiati)
            raw_mat <- getRawData(cotan_obj)
            cutoff_c <- round(nrow(raw_mat) * genes_cutoff, digits = 0L)
            expressed_genes <- Matrix::colSums(raw_mat > 0)
            cellsToDrop <- colnames(raw_mat)[expressed_genes <= cutoff_c]
            
            if (length(cellsToDrop) > 0) {
                cotan_obj <- dropGenesCells(cotan_obj, cells = cellsToDrop)
            }
            
            # Matrice post-filtrazione
            raw_mat_end <- getRawData(cotan_obj)
            end_genes <- nrow(raw_mat_end)
            end_cells <- ncol(raw_mat_end)
            
            dropped_g <- start_genes - end_genes
            dropped_c <- start_cells - end_cells
            
            log_stat(sprintf("Dropped %d genes and %d cells", dropped_g, dropped_c))
            
            # 3. Controllo Convergenza
            if (dropped_g == 0 && dropped_c == 0) {
                converged <- TRUE
                log_info("Matrix converged! No ghosts remain.\n")
            } else {
                iteration <- iteration + 1
            }
        }
        log_cotan_execution("Iterative dynamic filtering loop", is_complete = TRUE)

        log_cotan_execution("Finalizing thresholds & Nu estimation")
        cotan_obj <- findFullyExpressedGenes(cotan_obj, cellsThreshold = cells_threshold)
        cotan_obj <- findFullyExpressingCells(cotan_obj, genesThreshold = genes_threshold)
        cotan_obj <- estimateNuLinear(cotan_obj)
        log_cotan_execution("Finalizing thresholds & Nu estimation", is_complete = TRUE)

        final_cells <- ncol(getRawData(cotan_obj))
        final_genes <- nrow(getRawData(cotan_obj))

        log_info("Final matrix dimensions after cleaning:")
        log_stat(sprintf("Cells: %d", final_cells))
        log_stat(sprintf("Genes: %d\n", final_genes))

        log_header("Cleaning Complete", is_complete = TRUE)

        return(cotan_obj)
    }

    
#' Prepare COTAN Object for COEX Calculation
#'
#' @description
#' Estimates parameters (lambda, nu, dispersion) needed for COEX calculation.
#'
#' @param cotan_obj A `COTAN` object.
#' @param threshold Numeric. Threshold for convergence in the solver. Default is `0.01`.
#' @param cores Integer. Number of cores to use for parallel execution. Default is `1L`.
#' @param max_iterations Integer. Maximum number of iterations for the solver. Default is `100L`.
#' @param chunk_size Integer. Size of chunks for parallel processing. Default is `1024L`.
#'
#' @return An updated `COTAN` object ready for COEX calculation.
#'
#' @importFrom COTAN estimateLambdaLinear estimateNuLinear estimateDispersionViaSolver getLambda getNu
#' @importFrom stats mean median sd
#' @export
prepare_to_coex <- function(
  cotan_obj,
  threshold = 0.01,
  cores = 1L,
  max_iterations = 100L,
  chunk_size = 1024L
) {
    log_header("Preparing COTAN Object")

    log_cotan_execution("estimateLambdaLinear()")
    cotan_obj <- estimateLambdaLinear(cotan_obj)
    log_cotan_execution("estimateLambdaLinear()", is_complete = TRUE)

    lambda_values <- getLambda(cotan_obj)
    log_info("Lambda estimation complete. Summary statistics:")
    log_stat(sprintf("Mean Lambda: %f", mean(lambda_values)))
    log_stat(sprintf("Std Dev Lambda: %f", sd(lambda_values)))
    log_stat(sprintf("Median Lambda: %f", median(lambda_values)))
    log_stat(sprintf("Min Lambda: %f", min(lambda_values)))
    log_stat(sprintf("Max Lambda: %f\n", max(lambda_values)))

    log_cotan_execution("estimateNuLinear()")
    cotan_obj <- estimateNuLinear(cotan_obj)
    log_cotan_execution("estimateNuLinear()", is_complete = TRUE)

    nu_values <- getNu(cotan_obj)
    log_info("Nu estimation complete. Summary statistics:")
    log_stat(sprintf("Mean Nu: %f", mean(nu_values)))
    log_stat(sprintf("Std Dev Nu: %f", sd(nu_values)))
    log_stat(sprintf("Median Nu: %f", median(nu_values)))
    log_stat(sprintf("Min Nu: %f", min(nu_values)))
    log_stat(sprintf("Max Nu: %f\n", max(nu_values)))


    log_info("Preparing for COEX calculation with parameters:")
    log_stat(sprintf("Threshold: %f", threshold))
    log_stat(sprintf("Cores: %d", cores))
    log_stat(sprintf("Maximum Iterations: %d", max_iterations))
    log_stat(sprintf("Chunk Size: %d\n", chunk_size))

    log_cotan_execution("estimateDispersionViaSolver()")
    cotan_obj <- estimateDispersionViaSolver(
        cotan_obj,
        threshold = threshold,
        cores = cores,
        maxIterations = max_iterations,
        chunkSize = chunk_size
    )
    log_cotan_execution("estimateDispersionViaSolver()", is_complete = TRUE)

    log_header("Preparing COEX Complete", is_complete = TRUE)

    return(cotan_obj)
}

#' Calculate COEX for a COTAN Object
#'
#' @description
#' Calculates the genes' co-expression (COEX) matrix for a prepared COTAN object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param act_on_cells Boolean. Act on cells. Default is FALSE.
#' @param return_pp_fract Boolean. Return PP fraction. Default is FALSE.
#' @param optimize_for_speed Boolean. Try using the torch library to run matrix calculations. Default is TRUE.
#' @param device_str Character string. Device to use for calculations ("cpu", "cuda"). Default is "cuda".
#'
#' @return An updated `COTAN` object containing the calculated COEX matrix.
#'
#' @importFrom COTAN calculateCoex
#' @export
calculate_coex <- function(
  cotan_obj,
  act_on_cells = FALSE,
  return_pp_fract = FALSE,
  optimize_for_speed = TRUE,
  device_str = "cuda"
) {
    log_header("Calculating COEX")

    log_info("COEX calculation parameters:")
    log_stat(sprintf("Act on Cells: %s", act_on_cells))
    log_stat(sprintf("Return PP Fract: %s", return_pp_fract))
    log_stat(sprintf("Optimize for Speed: %s", optimize_for_speed))
    log_stat(sprintf("Device: %s\n", device_str))

    log_cotan_execution("calculateCoex()")
    cotan_obj <- calculateCoex(
        cotan_obj,
        actOnCells = act_on_cells,
        returnPPFract = return_pp_fract,
        optimizeForSpeed = optimize_for_speed,
        deviceStr = device_str
    )
    log_cotan_execution("calculateCoex()", is_complete = TRUE)

    log_header("Calculating COEX Complete", is_complete = TRUE)
    return(cotan_obj)
}

#' Calculate and Store GDI for a COTAN Object
#'
#' @description
#' Computes the Global Differential Expression Index (GDI), stores it, and saves the object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param out_dir Character string. Directory path where the final object will be saved. Default is `"."`.
#' @param cores Integer. Number of cores to use for parallel execution. Default is `1L`.
#' @param stat_type Character string. The type of statistic to use for GDI calculation ("S" or "G"). Default is "S".
#' @param rows_fraction Numeric. Fraction of rows to use for chunking in GDI. Default is 0.05.
#' @param chunk_size Integer. Size of the data chunks for GDI calculation. Default is 1024L.
#'
#' @return An updated `COTAN` object containing the calculated GDI metrics.
#'
#' @importFrom COTAN calculateGDI storeGDI
#' @export
calculate_and_store_gdi <- function(
  cotan_obj,
  out_dir = ".",
  cores = 1L,
  stat_type = "S",
  rows_fraction = 0.05,
  chunk_size = 1024L
) {
    log_header("Computing Global Differential Expression Index (GDI)")

    log_info("GDI calculation parameters:")
    log_stat(sprintf("Output Directory: %s", out_dir))
    log_stat(sprintf("Cores: %d", cores))
    log_stat(sprintf("Statistic Type: %s", stat_type))
    log_stat(sprintf("Rows Fraction: %f", rows_fraction))
    log_stat(sprintf("Chunk Size: %d\n", chunk_size))

    log_cotan_execution("calculateGDI & storeGDI")
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
    log_cotan_execution("calculateGDI & storeGDI", is_complete = TRUE)

    log_info("Saving the updated COTAN object...")

    if (!dir.exists(out_dir)) {
        log_stat(sprintf("Output directory '%s' does not exist. Creating it...", out_dir))
        dir.create(out_dir, recursive = TRUE)
    }

    out_file <- file.path(out_dir, "cotan_coex_gdi.rds")
    saveRDS(cotan_obj, file = out_file)

    log_stat(sprintf("Successfully saved to: %s", out_file))
    log_header("Calculation Complete", is_complete = TRUE)

    return(cotan_obj)
}
