# 5. Quality Control & Filtering

This document details the quality control (QC) filtering logic implemented in R and highlights the technical resolution for mitochondrial reads mapping on transcript-level matrices.

---

## 1. Quality Control Script Logic

Raw expression matrices are filtered to remove low-quality cells, doublets, and dying cells using two modular R scripts:
* **[filter_matrix.R](file:///home/deli/athena_mount/bin/filter_matrix.R)**: Driver script that parses command line arguments and drives the QC execution.
* **[lib_qc.R](file:///home/deli/athena_mount/bin/lib_qc.R)**: Contains helper functions to compute cell metrics, check mitochondrial mappings, and filter cell barcodes.
* **[lib_io.R](file:///home/deli/athena_mount/bin/lib_io.R)**: Handles loading of raw input RDS files (Seurat or SCE) and alevin outputs.

### CLI Parameters & Thresholds
Default parameters are declared in [nextflow.config](file:///home/deli/athena_mount/nextflow.config) and passed directly to the R driver script during workflow execution:
* `--min_features`: Minimum number of detected transcripts per cell (default = 200).
* `--max_features`: Maximum number of detected transcripts per cell (default = 8000, helps remove doublets).
* `--min_counts`: Minimum total UMI count per cell (default = 500).
* `--max_percent_mt`: Maximum allowed percentage of reads mapping to mitochondrial genes (default = 10.0%, indicating low cell stress).
* `--mt_transcripts`: Path to a text file containing mitochondrial transcript IDs.

---

## 2. Technical Challenge: Mitochondrial Read Identification

In standard scRNA-seq analyses, mitochondrial transcripts are identified in R using regex on gene symbols:
```r
mitochondrial_transcripts <- grep("^MT-|^mt-", rownames(raw_matrix), value = TRUE)
```

### The Problem
Because our modified index outputs **transcript-level matrices**, the row names of the matrix are **Ensembl Transcript IDs** (e.g., `ENSMUST00000188681.2` for mouse or `ENST00000373020.8` for human) instead of gene symbols. 
* The `grep("^MT-|^mt-")` query matches **zero** transcripts.
* The computed `percent_mt` evaluates to `0` for all cells.
* Low-quality cells with high mitochondrial content fail to be filtered out, introducing noise into downstream COTAN clustering.

---

## 3. The Resolution

To resolve this issue, we decoupled mitochondrial gene detection from regex and mapped it against a static transcript ID mapping file:

### Step 1: Pre-mapped Mitochondrial Transcripts File
* We query the reference GTF file before index modifications and locate all transcript IDs corresponding to the mitochondrial chromosome (`MT`).
* These IDs are written to a static configuration file at [config/mt_transcripts.txt](file:///home/deli/athena_mount/config/mt_transcripts.txt).

### Step 2: Integrated R QC Filter Logic
The mitochondrial detection logic in [lib_qc.R](file:///home/deli/athena_mount/bin/lib_qc.R) is updated to read these IDs and perform an intersection with the matrix rows:
```r
# Calculate cell QC metrics (nFeatures, nCounts, percent_mt)
calculate_qc_metrics <- function(raw_matrix, mt_ids = NULL) {
  ...
  if (!is.null(mt_ids) && length(mt_ids) > 0) {
    message("Finding mitochondrial transcripts using provided IDs list...")
    mitochondrial_transcripts <- intersect(rownames(raw_matrix), mt_ids)
  } else {
    message("Finding mitochondrial genes using regex match pattern...")
    mitochondrial_transcripts <- grep("^MT-|^mt-", rownames(raw_matrix), value = TRUE)
  }
  ...
}
```

This fallback ensures that:
1. Transcript-level matrices (where `mt_ids` are supplied) map and filter mitochondrial reads correctly.
2. Standard gene-symbol matrices (where `mt_ids` is omitted) continue to function using standard regex.
