#' Filter Seurat Object by Mitochondrial Transcript Percentage
#'
#' Calculates the percentage of mitochondrial counts per cell using a custom
#' list of transcript IDs and filters out cells exceeding a specified threshold.
#'
#' @param seurat_obj A `Seurat` object containing single-cell RNA-seq data.
#' @param mt_transcripts_list A character vector containing transcript IDs.
#' @param threshold Numeric. Maximum acceptable MT percentage. Default is 5.
#' @param output_dir Character. Optional directory to save the output object as an RDS file. Default is `NULL`.
#' @param file_name Character. Optional file name for saving the output object. Default is `"seurat_mt_filtered.rds"`.
#'
#' @return A new, filtered `Seurat` object. It has an additional metadata column `percent.mt`
#' representing the percentage of mitochondrial counts per cell.
#'
#' @importFrom Seurat PercentageFeatureSet
#' @importFrom SeuratObject Features
#' @importFrom project.base save_object
#' @importFrom project.logger log_header log_info log_warn log_error log_stat
#' @export
filter_mt_transcripts <- function(
  seurat_obj,
  mt_transcripts_list,
  threshold = 5,
  output_dir = NULL,
  file_name = "seurat_mt_filtered.rds"
) {
  log_header("filter mt transcripts")


  valid_mt <- base::intersect(mt_transcripts_list, SeuratObject::Features(seurat_obj))

  if (length(valid_mt) == 0) {
    log_error("No mitochondrial transcripts found in the matrix. Check that the ID format matches the Seurat rownames.",
      stop_exec = TRUE
    )
  }

  log_info("Filtering cells by mitochondrial transcript percentage...")

  seurat_obj[["percent.mt"]] <- Seurat::PercentageFeatureSet(
    seurat_obj,
    features = valid_mt,
    assay = "RNA"
  )

  # Optimized bracket notation instead of subset()
  seurat_filtered <- seurat_obj[, seurat_obj$percent.mt < threshold]

  if (!is.null(output_dir)) {
    log_info("Saving Seurat object...")
    save_object(seurat_filtered, output_dir, file_name)
  }

  log_stat(sprintf("Valid mitochondrial transcripts: %d", length(valid_mt)))
  log_stat(sprintf("Mitochondrial threshold: %s%%", as.character(threshold)))
  .log_seurat_change(seurat_obj, seurat_filtered)

  log_header(is_complete = TRUE)



  return(seurat_filtered)
}
