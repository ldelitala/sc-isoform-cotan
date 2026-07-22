#' Extract Differential Transcript Usage (DTU) Candidates
#'
#' @description
#' Identifies Differential Transcript Usage (DTU) events by cross-referencing
#' global transcript-to-transcript mutual exclusivity (via COEX scores and p-values)
#' with cluster-specific Differential Expression Analysis (DEA).
#' It reports ALL cell populations where the transcripts show a significant relative switch.
#'
#' @param cotan_object A `COTAN` object with calculated COEX and a valid clusterization.
#' @param clusterization_name Character. The name of the clusterization to use for DEA. Default is `"Known_Cell_Types"`.
#' @param p_value_threshold Numeric. Maximum p-value to consider a COEX score significant. Default is `0.05`.
#' @param coex_threshold Numeric. Maximum COEX score (must be negative) to define mutual exclusivity. Default is `-0.1`.
#' @param min_dea_contrast Numeric. Minimum absolute difference in enrichment scores to define a valid switch.
#'                         Default is `1.0`.
#' @param output_directory Character. Directory to save the output CSV. Default is `NULL`.
#' @param file_name Character. Name of the output file. Default is `"dtu_candidates.csv"`.
#'
#' @return A `data.frame` containing the identified DTU events.
#'
#' @importFrom COTAN DEAOnClusters getGenesCoex calculatePValue getMetadataGenes
#' @importFrom utils write.csv
#' @export
extract_dtu_candidates <- function(
  cotan_object,
  clusterization_name = "Known_Cell_Types",
  p_value_threshold = 0.05,
  coex_threshold = -0.1,
  min_dea_contrast = 1.0,
  output_directory = NULL,
  file_name = "dtu_candidates.csv",
  cores = 1L,
  chunk_size = 1024L
) {
    log_header("DTU Candidates Extraction")

    log_cotan_execution("DEAOnClusters()", clName = clusterization_name)
    diff_expression_matrix <- COTAN::DEAOnClusters(cotan_object, clName = clusterization_name)
    log_cotan_execution("DEAOnClusters()", is_complete = TRUE)

    log_info("Extracting global co-expression (COEX) matrix...")
    coex_matrix <- COTAN::getGenesCoex(cotan_object)

    log_cotan_execution("calculatePValue()")
    p_value_matrix <- COTAN::calculatePValue(cotan_object, cores = cores, chunkSize = chunk_size)
    log_cotan_execution("calculatePValue()", is_complete = TRUE)

    log_info("Retrieving transcript-to-gene mapping...")
    feature_metadata <- COTAN::getMetadataGenes(cotan_object)

    if (!"gene_id" %in% colnames(feature_metadata)) {
        log_error(
            "Column 'gene_id' not found in feature metadata. Did you run add_gene_info_from_t2g?",
            stop_exec = TRUE
        )
    }

    log_info("Filtering to keep only transcripts with at least 2 isoforms...")
    multi_trancripts_genes <- Filter(
        function(transcripts) length(transcripts) >= 2,
        split(rownames(feature_metadata), feature_metadata$gene_id)
    )
    log_stat(sprintf("Genes with multiple transcripts: %d", length(multi_trancripts_genes)))

    log_info("Scanning for mutually exclusive transcripts with significant cluster switches...")

    dtu_candidates_list <- list()
    missing_count <- 0
    weak_contrast_count <- 0

    for (current_gene in names(multi_trancripts_genes)) {
        valid_transcripts <- intersect(multi_trancripts_genes[[current_gene]], rownames(coex_matrix))

        if (length(valid_transcripts) < 2) {
            missing_count <- missing_count + 1
            next
        }

        subset_coex <- as.matrix(coex_matrix[valid_transcripts, valid_transcripts, drop = FALSE])
        subset_p_value <- as.matrix(p_value_matrix[valid_transcripts, valid_transcripts, drop = FALSE])

        upper_subset_coex <- upper.tri(subset_coex)

        significant_pairs_indices <- which(
            upper_subset_coex &
                subset_coex <= coex_threshold &
                subset_p_value <= p_value_threshold,
            arr.ind = TRUE
        )

        if (nrow(significant_pairs_indices) > 0) {
            for (row_index in seq_len(nrow(significant_pairs_indices))) {
                transcript_A <- valid_transcripts[significant_pairs_indices[row_index, 1]]
                transcript_B <- valid_transcripts[significant_pairs_indices[row_index, 2]]

                # --- MULTI-CLUSTER DELTA LOGIC ---
                dea_vector_A <- diff_expression_matrix[transcript_A, ]
                dea_vector_B <- diff_expression_matrix[transcript_B, ]

                # Calculate relative contrast (A - B)
                dea_contrast <- dea_vector_A - dea_vector_B

                # Find ALL clusters where A significantly dominates B
                dominant_clusters_A <- colnames(diff_expression_matrix)[dea_contrast >= min_dea_contrast]

                # Find ALL clusters where B significantly dominates A (Delta is negative)
                dominant_clusters_B <- colnames(diff_expression_matrix)[dea_contrast <= -min_dea_contrast]

                # Validation: DTU requires a definitive switch.
                # Both transcripts MUST dominate in at least one cluster to be a valid candidate.
                if (length(dominant_clusters_A) == 0 || length(dominant_clusters_B) == 0) {
                    weak_contrast_count <- weak_contrast_count + 1
                    next
                }

                # Capture the absolute maximum deltas for sorting/metrics
                max_delta_A <- max(dea_contrast[dominant_clusters_A])
                max_delta_B <- abs(min(dea_contrast[dominant_clusters_B]))

                dtu_candidates_list[[length(dtu_candidates_list) + 1]] <- data.frame(
                    Gene = current_gene,
                    Transcript_A = transcript_A,
                    Transcript_B = transcript_B,
                    COEX_Score = subset_coex[
                        significant_pairs_indices[row_index, 1],
                        significant_pairs_indices[row_index, 2]
                    ],
                    P_Value = subset_p_value[
                        significant_pairs_indices[row_index, 1],
                        significant_pairs_indices[row_index, 2]
                    ],
                    # Usiamo I(list(...)) per inserire l'intero array dentro una singola cella del dataframe
                    Enriched_Cell_Types_A = I(list(dominant_clusters_A)),
                    Enriched_Cell_Types_B = I(list(dominant_clusters_B)),
                    Max_Contrast_A = max_delta_A,
                    Max_Contrast_B = max_delta_B,
                    stringsAsFactors = FALSE
                )
            }
        }
    }

    # 5. Reporting and Data Assembly
    if (missing_count > 0) {
        log_warn(sprintf(
            "Defensive programming triggered: %d genes were skipped because one or more transcripts were missing from the COEX matrix (likely dropped due to zero variance).", # nolint
            missing_count
        ))
    }

    if (weak_contrast_count > 0) {
        log_info(sprintf(
            "Filtered out %d transcript pairs lacking a reciprocal cluster switch exceeding the Delta threshold (Delta >= %g).", # nolint
            weak_contrast_count, min_dea_contrast
        ))
    }

    if (length(dtu_candidates_list) > 0) {
        final_dtu_dataframe <- do.call(rbind, dtu_candidates_list)
        # Sort by COEX_Score ascending (most negative / strongest mutual exclusivity first)
        final_dtu_dataframe <- final_dtu_dataframe[order(final_dtu_dataframe$COEX_Score), ]

        log_stat(sprintf(
            "Identified %d DTU events across %d unique genes.",
            nrow(final_dtu_dataframe), length(unique(final_dtu_dataframe$Gene))
        ))
    } else {
        log_warn("No DTU events found matching the specified thresholds.")
        final_dtu_dataframe <- data.frame()
    }

    # 6. Disk I/O Operations
    if (!is.null(output_directory) && nrow(final_dtu_dataframe) > 0) {
        if (!grepl("\\.csv$", file_name, ignore.case = TRUE)) {
            file_name <- paste0(file_name, ".csv")
        }

        file_path <- file.path(output_directory, file_name)

        if (!dir.exists(output_directory)) {
            dir.create(output_directory, recursive = TRUE)
        }

        log_info(sprintf("Saving DTU results to CSV: %s", file_path))

        # Creiamo una copia per il CSV dove "appiattiamo" gli array in stringhe
        export_dataframe <- final_dtu_dataframe
        export_dataframe$Enriched_Cell_Types_A <-
            vapply(export_dataframe$Enriched_Cell_Types_A, paste, collapse = "; ", character(1))
        export_dataframe$Enriched_Cell_Types_B <-
            vapply(export_dataframe$Enriched_Cell_Types_B, paste, collapse = "; ", character(1))

        utils::write.csv(export_dataframe, file = file_path, row.names = FALSE)

        # Suggerimento opzionale: salvare anche in formato nativo R (.rds) che preserva gli array
        rds_file_path <- sub("\\.csv$", ".rds", file_path)
        log_info(sprintf("Saving native R object (with arrays) to: %s", rds_file_path))
        saveRDS(final_dtu_dataframe, file = rds_file_path)
    }

    log_header("DTU Extraction Complete", is_complete = TRUE)
    return(final_dtu_dataframe)
}
