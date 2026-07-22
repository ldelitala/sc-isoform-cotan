#' Extract Differential Transcript Usage (DTU) Candidates
#'
#' @param cotan_object A `COTAN` object with calculated COEX, a valid clusterization, stored DEA, and stored p-values.
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
#' @importFrom COTAN getGenesCoex getMetadataGenes getClustersCoex
#' @importFrom utils write.csv
#' @import project.logger
#' @import project.utils
#' @export
extract_dtu_candidates <- function(
  cotan_object,
  clusterization_name = "Known_Cell_Types",
  p_value_threshold = 0.05,
  coex_threshold = -0.1,
  min_dea_contrast = 1.0,
  output_directory = NULL,
  file_name = "dtu_candidates.csv"
) {
    log_header("extract dtu candidates")

    log_info("Retrieving stored inputs...")
    
    # Try exact name, then with CL_ prefix
    all_dea <- COTAN::getClustersCoex(cotan_object)
    diff_expression_matrix <- NULL
    if (clusterization_name %in% names(all_dea)) {
        diff_expression_matrix <- all_dea[[clusterization_name]]
    } else {
        prefixed_name <- paste0("CL_", clusterization_name)
        if (prefixed_name %in% names(all_dea)) {
            diff_expression_matrix <- all_dea[[prefixed_name]]
        }
    }
    
    coex_matrix <- COTAN::getGenesCoex(cotan_object)
    
    # Retrieve p-values from package cache, object attribute, or metaDataset attribute
    p_value_matrix <- NULL
    tryCatch({
        key <- project.cotan:::.get_object_key(cotan_object)
        p_value_matrix <- project.cotan:::.p_values_cache[[key]]
    }, error = function(e) {})
    
    if (is.null(p_value_matrix)) {
        p_value_matrix <- attr(cotan_object, "p_values")
    }
    if (is.null(p_value_matrix)) {
        p_value_matrix <- attr(cotan_object@metaDataset, "p_values")
    }

    if (is.null(diff_expression_matrix) || is.null(p_value_matrix)) {
        log_error(sprintf(
            "Missing inputs: DEA matrix is %s, P-value matrix is %s. Run dea_on_clusters() and calculate_p_value() first.",
            if (is.null(diff_expression_matrix)) "NULL" else "OK",
            if (is.null(p_value_matrix)) "NULL" else "OK"
        ), stop_exec = TRUE)
    }

    feature_metadata <- COTAN::getMetadataGenes(cotan_object)
    if (!"gene_id" %in% colnames(feature_metadata)) {
        log_error("Column 'gene_id' not found in metadata. Run add_gene_info_from_t2g first.", stop_exec = TRUE)
    }

    log_info("Identifying genes with multiple transcripts...")
    multi_genes <- Filter(function(x) length(x) >= 2, split(rownames(feature_metadata), feature_metadata$gene_id))

    log_info("Scanning for DTU candidates...")
    log_info("Phase 1: Filter transcript pairs by mutual exclusivity (COEX and P-value thresholds).")
    log_info("Phase 2: Check DEA contrast across clusters for reciprocal expression switches.")

    dtu_list <- list()
    missing_count <- 0
    weak_count <- 0
    zero_pairs_count <- 0

    all_evaluated_coex <- numeric(0)
    all_evaluated_pvals <- numeric(0)
    all_evaluated_contrasts <- numeric(0)

    for (gene in names(multi_genes)) {
        transcripts <- intersect(multi_genes[[gene]], rownames(coex_matrix))
        if (length(transcripts) < 2) {
            missing_count <- missing_count + 1
            next
        }

        # Convert subsets to base R matrices to avoid Matrix package conflicts with which()
        sub_coex <- as.matrix(coex_matrix[transcripts, transcripts, drop = FALSE])
        sub_pval <- as.matrix(p_value_matrix[transcripts, transcripts, drop = FALSE])

        pairs <- which(
            upper.tri(sub_coex) &
            sub_coex <= coex_threshold &
            sub_pval <= p_value_threshold,
            arr.ind = TRUE
        )

        if (nrow(pairs) == 0) {
            zero_pairs_count <- zero_pairs_count + 1
            next
        }

        for (i in seq_len(nrow(pairs))) {
            t_A <- transcripts[pairs[i, 1]]
            t_B <- transcripts[pairs[i, 2]]

            coex_val <- sub_coex[pairs[i, 1], pairs[i, 2]]
            pval_val <- sub_pval[pairs[i, 1], pairs[i, 2]]

            all_evaluated_coex <- c(all_evaluated_coex, coex_val)
            all_evaluated_pvals <- c(all_evaluated_pvals, pval_val)

            contrast <- diff_expression_matrix[t_A, ] - diff_expression_matrix[t_B, ]
            all_evaluated_contrasts <- c(all_evaluated_contrasts, max(abs(contrast)))

            cl_A <- names(contrast)[contrast >= min_dea_contrast]
            cl_B <- names(contrast)[contrast <= -min_dea_contrast]

            if (length(cl_A) == 0 || length(cl_B) == 0) {
                weak_count <- weak_count + 1
                next
            }

            dtu_list[[length(dtu_list) + 1]] <- data.frame(
                Gene = gene,
                Transcript_A = t_A, Transcript_B = t_B,
                COEX_Score = coex_val, 
                P_Value = pval_val,
                Enriched_Cell_Types_A = I(list(cl_A)), Enriched_Cell_Types_B = I(list(cl_B)),
                Max_Contrast_A = max(contrast[cl_A]), Max_Contrast_B = abs(min(contrast[cl_B])),
                stringsAsFactors = FALSE
            )
        }
    }

    log_info("Assembling results...")
    if (length(dtu_list) > 0) {
        final_df <- do.call(rbind, dtu_list)
        final_df <- final_df[order(final_df$COEX_Score), ]
    } else {
        final_df <- data.frame()
    }

    if (!is.null(output_directory) && nrow(final_df) > 0) {
        if (!dir.exists(output_directory)) dir.create(output_directory, recursive = TRUE)
        csv_path <- file.path(output_directory, sub("\\.csv$", "", file_name, ignore.case = TRUE))

        log_info("Formatting cell type arrays for CSV export...")
        export_df <- final_df
        export_df$Enriched_Cell_Types_A <- vapply(export_df$Enriched_Cell_Types_A, paste, collapse = "; ", character(1))
        export_df$Enriched_Cell_Types_B <- vapply(export_df$Enriched_Cell_Types_B, paste, collapse = "; ", character(1))

        utils::write.csv(export_df, file = paste0(csv_path, ".csv"), row.names = FALSE)
        saveRDS(final_df, file = paste0(csv_path, ".rds"))
    }

    if (missing_count > 0) {
        log_warn(sprintf("Skipped %d genes with missing transcripts in COEX matrix.", missing_count))
    }
    
    # Detailed math breakdown log
    log_stat(sprintf("Genes with multiple transcripts: %d", length(multi_genes)))
    if (zero_pairs_count > 0) {
        log_stat(sprintf("Genes with zero significant mutually exclusive pairs: %d", zero_pairs_count))
    }
    
    genes_with_pairs <- length(multi_genes) - zero_pairs_count - missing_count
    log_stat(sprintf("Genes with at least one significant mutually exclusive pair: %d", genes_with_pairs))
    log_stat(sprintf("Total significant transcript pairs evaluated: %d", length(all_evaluated_coex)))

    if (weak_count > 0) {
        log_stat(sprintf("Filtered out %d transcript pairs lacking reciprocal cluster switch.", weak_count))
    }
    if (nrow(final_df) > 0) {
        log_stat(sprintf("Identified %d DTU events across %d unique genes.", nrow(final_df), length(unique(final_df$Gene))))
    }

    if (length(all_evaluated_coex) > 0) {
        log_stat(sprintf(
            "Significant pairs coex scores: min = %.4f, median = %.4f, mean = %.4f, max = %.4f",
            min(all_evaluated_coex), median(all_evaluated_coex), mean(all_evaluated_coex), max(all_evaluated_coex)
        ))
        log_stat(sprintf(
            "Significant pairs p-values: min = %.4e, median = %.4e, mean = %.4e, max = %.4e",
            min(all_evaluated_pvals), median(all_evaluated_pvals), mean(all_evaluated_pvals), max(all_evaluated_pvals)
        ))
        log_stat(sprintf(
            "Significant pairs max DEA contrasts: min = %.4f, median = %.4f, mean = %.4f, max = %.4f",
            min(all_evaluated_contrasts), median(all_evaluated_contrasts), mean(all_evaluated_contrasts), max(all_evaluated_contrasts)
        ))
    }

    log_header(is_complete = TRUE)
    return(final_df)
}
