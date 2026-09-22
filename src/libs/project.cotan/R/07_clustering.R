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
#' @import project.logger
#' @import project.utils
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
    log_header("calculate gdi")
    log_cotan_execution("calculateGDI()", statType = stat_type, rowsFraction = rows_fraction, cores = cores, chunkSize = chunk_size)

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

    log_cotan_execution(is_complete = TRUE)

    if (!is.null(output_dir)) {
        log_info("Saving COTAN object...")
        save_object(cotan_obj, output_dir, file_name)
    }

    log_header(is_complete = TRUE)

    return(cotan_obj)
}

#' Perform Uniform Clustering and Merging
#'
#' @description
#' Performs GDI-based uniform transcript clustering to find homogenous cell populations,
#' then merges highly similar clusters to prevent over-clustering.
#' Automatically extracts the resulting clusters and co-expression matrices and stores
#' them back into the COTAN object.
#'
#' @param cotan_obj A `COTAN` object.
#' @param gdi_threshold Numeric. Threshold for GDI clustering.
#' @param cores Integer. Number of cores to use. Default is 1L.
#' @param optimize_for_speed Boolean. Try using the torch library to run matrix calculations. Default is TRUE.
#' @param device_str Character string. Device to use for calculations ("cpu", "cuda"). Default is "cuda".
#' @param save_obj Boolean. Save intermediate COTAN objects and plots to disk. Default is FALSE.
#' @param output_dir Character. Optional directory to save intermediate outputs and the final output object.
#'                   Default is `NULL`.
#' @param file_name Character. Optional file name for saving the final output object.
#'                  Default is `"cotan_clustered.rds"`.
#' @param checker A `BaseUniformityCheck` object. Default is `NULL`.
#' @param initial_resolution Numeric. Default is 0.8.
#' @param max_iterations Integer. Default is 25L.
#' @param use_dea Boolean. Default is TRUE.
#' @param distance Character. Default is `NULL`.
#' @param use_coex_eigen Boolean. Default is FALSE.
#' @param data_method Character. Default is `""`.
#' @param genes_sel Character. Default is `"HVG_Seurat"`.
#' @param num_genes Integer. Default is 2000L.
#' @param num_reduced_comp Integer. Default is 25L.
#' @param hclust_method Character. Default is `"ward.D2"`.
#' @param initial_clusters Character vector. Default is `NULL`.
#' @param minimum_ut_cluster_size Integer. Default is 50L.
#' @param initial_iteration Integer. Default is 1L.
#' @param clusters A clusterization to merge. Default is `NULL`.
#' @param checkers A list of uniformity checkers. Default is `NULL`.
#' @param batch_size Integer. Default is 0L.
#' @param all_check_results A data frame. Default is `data.frame()`.
#'
#' @return A clustered `COTAN` object with "split" and "merged" clusterizations added.
#'
#' @importFrom COTAN cellsUniformClustering mergeUniformCellsClusters addClusterization
#' @import project.logger
#' @import project.utils
#' @export
perform_clustering <- function(
  cotan_obj,
  cl_name = "merged",
  gdi_threshold = NaN,
  cores = 1L,
  optimize_for_speed = TRUE,
  device_str = "cuda",
  save_obj = FALSE,
  output_dir = NULL,
  file_name = "cotan_clustered.rds",
  checker = NULL,
  initial_resolution = 0.8,
  max_iterations = 25L,
  use_dea = TRUE,
  distance = NULL,
  use_coex_eigen = FALSE,
  data_method = "",
  genes_sel = "HVG_Seurat",
  num_genes = 2000L,
  num_reduced_comp = 25L,
  hclust_method = "ward.D2",
  initial_clusters = NULL,
  minimum_ut_cluster_size = 50L,
  initial_iteration = 1L,
  clusters = NULL,
  checkers = NULL,
  batch_size = 0L,
  all_check_results = data.frame()
) {
    log_header("perform uniform clustering")

    if (save_obj && (is.null(output_dir) || output_dir == "")) {
        log_warn("save_obj is TRUE but output_dir is empty. Setting save_obj to FALSE to prevent writing in root.")
        save_obj <- FALSE
    }

    out_dir_val <- if (is.null(output_dir)) "" else output_dir


    log_info("Starting Step 1/2: Splitting clusters...")
    log_cotan_execution("cellsUniformClustering()",
        GDIThreshold = gdi_threshold,
        cores = cores,
        optimizeForSpeed = optimize_for_speed,
        deviceStr = device_str,
        saveObj = save_obj,
        outDir = out_dir_val,
        checker = checker,
        initialResolution = initial_resolution,
        maxIterations = max_iterations,
        useDEA = use_dea,
        distance = distance,
        useCoexEigen = use_coex_eigen,
        dataMethod = data_method,
        genesSel = genes_sel,
        numGenes = num_genes,
        numReducedComp = num_reduced_comp,
        hclustMethod = hclust_method,
        minimumUTClusterSize = minimum_ut_cluster_size,
        initialIteration = initial_iteration
   )
    old_log_level <- getOption("COTAN.LogLevel", default = 1L)
    setLoggingLevel(0L)

    split_list <- COTAN::cellsUniformClustering(
        objCOTAN = cotan_obj,
        checker = checker,
        GDIThreshold = gdi_threshold,
        initialResolution = initial_resolution,
        maxIterations = max_iterations,
        cores = cores,
        optimizeForSpeed = optimize_for_speed,
        deviceStr = device_str,
        useDEA = use_dea,
        distance = distance,
        useCoexEigen = use_coex_eigen,
        dataMethod = data_method,
        genesSel = genes_sel,
        numGenes = num_genes,
        numReducedComp = num_reduced_comp,
        hclustMethod = hclust_method,
        initialClusters = initial_clusters,
        minimumUTClusterSize = minimum_ut_cluster_size,
        initialIteration = initial_iteration,
        saveObj = save_obj,
        outDir = out_dir_val
    )
    setLoggingLevel(old_log_level)

    log_cotan_execution("cellsUniformClustering()", is_complete = TRUE)

    log_info("Adding 'split' clusterization to the COTAN object...")
    cotan_obj <- COTAN::addClusterization(
        objCOTAN = cotan_obj,
        clName = "split",
        clusters = split_list[["clusters"]],
        coexDF = split_list[["coex"]],
        override = TRUE
    )

    num_split_clusters <- length(unique(split_list[["clusters"]]))

    log_info("Starting Step 2/2: Merging clusters...")
    log_cotan_execution("mergeUniformCellsClusters()",
        GDIThreshold = gdi_threshold,
        cores = cores,
        optimizeForSpeed = optimize_for_speed,
        deviceStr = device_str,
        saveObj = save_obj,
        outDir = out_dir_val,
        clusters = length(unique(split_list[["clusters"]])), # we just print num
        checkers = checkers,
        batchSize = batch_size,
        useDEA = use_dea,
        distance = distance,
        hclustMethod = hclust_method,
        allCheckResults = all_check_results,
        initialIteration = initial_iteration
    )
    old_log_level <- getOption("COTAN.LogLevel", default = 1L)
    setLoggingLevel(0L)
    merged_list <- COTAN::mergeUniformCellsClusters(
        objCOTAN = cotan_obj,
        clusters = clusters,
        checkers = checkers,
        GDIThreshold = gdi_threshold,
        batchSize = batch_size,
        cores = cores,
        optimizeForSpeed = optimize_for_speed,
        deviceStr = device_str,
        useDEA = use_dea,
        distance = distance,
        hclustMethod = hclust_method,
        allCheckResults = all_check_results,
        initialIteration = initial_iteration,
        saveObj = save_obj,
        outDir = out_dir_val
    )
    setLoggingLevel(old_log_level)
    log_cotan_execution("mergeUniformCellsClusters()", is_complete = TRUE)

    log_info("Adding 'merged' clusterization to the COTAN object...")
    cotan_obj <- COTAN::addClusterization(
        objCOTAN = cotan_obj,
        clName = cl_name,
        clusters = merged_list[["clusters"]],
        coexDF = merged_list[["coex"]],
        override = TRUE
    )

    if (!is.null(output_dir)) {
        save_object(cotan_obj, output_dir, file_name)
    }

    log_stat(sprintf("Generated %d uniform clusters.", num_split_clusters))
    log_stat(sprintf(
        "Clusters reduced from %d to %d after merging.", num_split_clusters,
        length(unique(merged_list[["clusters"]]))
    ))

    log_header(is_complete = TRUE)

    return(cotan_obj)
}
