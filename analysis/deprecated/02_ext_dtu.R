# DEPRECATED (S7): provenance only — see README.md in this directory.
#' Extract DTU Candidates (Mutual Exclusivity)
#'
#' @description
#' Extracts transcript-to-transcript COEX values for transcripts sharing the same 
#' parent gene and identifies pairs with significant negative COEX coefficients.
#'
#' @param cotan_obj A `COTAN` object with a calculated COEX matrix.
#' @param p_value_threshold Numeric. The significance threshold for the P-value. Default is 0.05.
#'
#' @return A data.frame of significantly mutually exclusive DTU candidates.
#'
#' @importFrom COTAN getNumCells
#' @importFrom stats pchisq
#' @export
extract_dtu_candidates <- function(cotan_obj, p_value_threshold = 0.05) {
    log_header("Extracting DTU Candidates")
    
    log_info("Retrieving COEX matrix and cell count...")
    coex_matrix <- COTAN::getCOEX(cotan_obj)
    num_cells <- COTAN::getNumCells(cotan_obj)
    
    transcripts <- rownames(coex_matrix)
    if (is.null(transcripts)) {
        log_error("COEX matrix does not have row names (transcripts expected).", stop_exec = TRUE)
    }

    log_info("Mapping transcripts to parent genes...")
    # Assuming standard format: "GENE_TRANSCRIPT" (e.g., "ENSG..._ENST...")
    parent_genes <- sub("_.*", "", transcripts)
    
    # Create an initial mapping
    transcript_info <- data.frame(
        Transcript = transcripts, 
        Gene = parent_genes, 
        stringsAsFactors = FALSE
    )

    log_info("Calculating COEX scores and P-values for transcript pairs...")
    
    # Merge to find pairs sharing the same gene
    pairs <- merge(transcript_info, transcript_info, by = "Gene", suffixes = c("_A", "_B"))
    
    # Filter out self-comparisons and duplicates (keep unique combinations)
    pairs <- pairs[pairs$Transcript_A < pairs$Transcript_B, ]
    
    if (nrow(pairs) == 0) {
        log_warn("No transcript pairs sharing the same parent gene found.")
        return(data.frame())
    }

    # Extract COEX scores for the pairs
    idx_A <- match(pairs$Transcript_A, rownames(coex_matrix))
    idx_B <- match(pairs$Transcript_B, colnames(coex_matrix))
    
    # Using matrix indexing to pull exact coordinates
    pairs$COEX_score <- coex_matrix[cbind(idx_A, idx_B)]
    
    # Apply COTAN theoretical model for p-value: P(chi^2(1) > m * C_ij^2)
    pairs$chi_sq_val <- num_cells * (pairs$COEX_score^2)
    pairs$P_value <- stats::pchisq(pairs$chi_sq_val, df = 1, lower.tail = FALSE)
    
    log_info("Filtering for significant mutual exclusivity (Negative COEX)...")
    dtu_candidates <- pairs[pairs$COEX_score < 0 & pairs$P_value < p_value_threshold, ]
    
    # Sort by significance
    dtu_candidates <- dtu_candidates[order(dtu_candidates$P_value), ]
    
    log_stat(sprintf("Status: Identified %d mutually exclusive transcript pairs.", nrow(dtu_candidates)))
    log_header("DTU Candidates Extraction Complete", is_complete = TRUE)

    return(dtu_candidates)
}
