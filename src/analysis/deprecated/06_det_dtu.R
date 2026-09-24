# DEPRECATED (S7): provenance only — see README.md in this directory.
#' Detect Differential Transcript Usage (DTU) using COTAN
#'
#' @description
#' Identifies DTU events by combining global transcript-pair exclusivity (negative coex) 
#' and cluster-specific opposite enrichment signals (one transcript enriched, another depleted).
#'
#' @param cotan_obj A `COTAN` object.
#' @param cl_name Character. Name of the clusterization to use. Default is `"merged"`.
#' @param p_value_threshold Numeric. P-value threshold for global transcript exclusivity. Default is 0.05.
#' @param delimiter Character. Delimiter separating gene ID and transcript ID in row names. Default is `_`.
#'
#' @return A data.frame containing detected DTU events, including gene name, transcript pairs, 
#' cluster, global COEX, cluster COEX scores, and a combined DTU score.
#'
#' @importFrom COTAN getGenesCoex getClusterizationData getNumCells
#' @importFrom stats pchisq
#' @export
detect_cotan_dtu <- function(
  cotan_obj,
  cl_name = "merged",
  p_value_threshold = 0.05,
  delimiter = "_"
) {
    log_header("Detecting COTAN DTU Events")

    log_info("Retrieving global COEX and clusterization data...")
    global_coex <- COTAN::getGenesCoex(cotan_obj)
    num_cells <- COTAN::getNumCells(cotan_obj)

    cl_data <- COTAN::getClusterizationData(cotan_obj, clName = cl_name)
    cluster_coex <- cl_data[["coex"]]

    if (is.null(cluster_coex) || ncol(cluster_coex) == 0) {
        log_error("No cluster-specific COEX found for the specified clusterization.", stop_exec = TRUE)
    }

    transcripts <- rownames(global_coex)
    parent_genes <- sub(paste0(delimiter, ".*"), "", transcripts)

    # Group transcripts by gene
    gene_to_transcripts <- split(transcripts, parent_genes)
    multi_trans_genes <- names(gene_to_transcripts)[sapply(gene_to_transcripts, length) >= 2]

    log_stat(sprintf("Scanning %d multi-transcript genes...", length(multi_trans_genes)))

    dtu_events <- list()

    for (gene in multi_trans_genes) {
        gene_trans <- gene_to_transcripts[[gene]]
        num_trans <- length(gene_trans)

        # Compare all unique pairs
        for (i in 1:(num_trans - 1)) {
            for (j in (i + 1):num_trans) {
                t_A <- gene_trans[i]
                t_B <- gene_trans[j]

                # Global exclusivity check
                val_coex <- global_coex[t_A, t_B]
                if (val_coex >= 0) next

                chi_sq <- num_cells * (val_coex^2)
                pval <- stats::pchisq(chi_sq, df = 1, lower.tail = FALSE)
                if (pval >= p_value_threshold) next

                # Check across each cluster for opposite signs
                for (cl in colnames(cluster_coex)) {
                    score_A <- cluster_coex[t_A, cl]
                    score_B <- cluster_coex[t_B, cl]

                    # Opposite signs check (one enriched, one depleted)
                    if (score_A * score_B < 0) {
                        dtu_score <- abs(score_A - score_B) * abs(val_coex)
                        
                        dtu_events[[length(dtu_events) + 1]] <- data.frame(
                            Gene = gene,
                            Transcript_A = t_A,
                            Transcript_B = t_B,
                            Cluster = cl,
                            Global_COEX = val_coex,
                            Exclusivity_PVal = pval,
                            Cluster_COEX_A = score_A,
                            Cluster_COEX_B = score_B,
                            DTU_Score = dtu_score,
                            stringsAsFactors = FALSE
                        )
                    }
                }
            }
        }
    }

    if (length(dtu_events) == 0) {
        log_warn("No DTU events detected matching the criteria.")
        return(data.frame())
    }

    dtu_df <- do.call(rbind, dtu_events)
    # Sort by DTU score descending
    dtu_df <- dtu_df[order(-dtu_df$DTU_Score), ]

    log_stat(sprintf("Status: Detected %d DTU events across all clusters.", nrow(dtu_df)))
    log_header("DTU Detection Complete", is_complete = TRUE)

    return(dtu_df)
}
