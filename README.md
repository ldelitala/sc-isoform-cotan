# Isoform-Aware scRNA-seq Analysis with COTAN

This repository contains data, configuration files, and automated scripts for single-cell RNA-seq processing, quality control filtering, and downstream analysis. 

This project serves as the dry-lab codebase for a **Bachelor's Thesis in Computer Science** evaluating the performance of the **COTAN** algorithm on transcript-level matrices.

---

## 1. Project Objective
The goal of this thesis is to determine if **COTAN** (CO-expression Table Analysis), an algorithm optimized for sparse single-cell matrices, can successfully yield isoform-aware co-expression networks and resolve cell clusters even when using faulty, 3'-biased transcript-level datasets.

The **verification step** of this thesis consists of validating COTAN's downstream results (co-expression tables, cell clusters, marker genes) by comparing them directly against **pre-existing biological knowledge** of the target genome (such as known isoform behavior, established cell-type markers, and reference databases). 

If time permits, a secondary exploratory path will involve running the **SCALPEL** pipeline to generate alternative cell-by-isoform count matrices to evaluate if a dedicated splicing quantification pipeline changes or improves COTAN's performance.

---

## 2. Directory Structure

```
athena_mount/
├── README.md               # Main project introduction & entry point
├── main.nf                 # Primary Nextflow DSL2 pipeline workflow
├── nextflow.config         # Unified pipeline configuration and limits
├── bin/                    # Executables automatically added to task PATH
│   ├── ingest_srr.sh       # SRA layout query and download coordinator
│   ├── download_fastq.sh   # Paired-end fastq download worker
│   ├── download_bam.sh     # BAM-to-FASTQ conversion worker
│   ├── filter_matrix.R     # R quality control filtering driver
│   ├── lib_io.R            # IO helpers for matrix loading
│   └── lib_qc.R            # QC threshold calculation helpers
├── docs/                   # Thesis workflow and project documentation
├── config/                 # Static configuration files (e.g. mt_transcripts.txt)
├── cache/                  # Download caches (NCBI SRA, Singularity containers)
├── datasets/               # Extracted FASTQ datasets (grouped by dataset/sample)
├── references/             # Reference genomes and simpleaf index directories
├── runs/                   # Execution directories for Nextflow runs and outputs
├── scripts/                # Helper tools and setup scripts (e.g. apply_cheat_index.py)
└── filtered/               # Final filtered RDS matrices ready for COTAN
```

---

## 3. Project Documentation Index

Refer to the detailed guides in the `docs/` folder in the logical reading order:

1. **[1. Configuration & Parameter Guide](file:///home/deli/athena_mount/docs/1_configuration_parameters.md)**: Details all workflow parameters, QC thresholds, resource limits, and Singularity settings.
2. **[2. Cluster Resource & Thread Management](file:///home/deli/athena_mount/docs/2_cluster_resource_management.md)**: Explains priority scheduling (`nice`/`ionice`), memory calculations, RAM disk staging, and thread configurations.
3. **[3. Data Ingestion & Storage Policy](file:///home/deli/athena_mount/docs/3_data_ingestion.md)**: Details standard paired-end vs. BAM-to-FASTQ reconstructed SRA downloads and storage optimization policy.
4. **[4. Transcript-Level Quantification](file:///home/deli/athena_mount/docs/4_transcript_quantification.md)**: Explains the simpleaf index identity mapping cheat and Nextflow alignment run parameters.
5. **[5. Quality Control & Filtering](file:///home/deli/athena_mount/docs/5_qc_filtering.md)**: Details the R script filtering logic and the mitochondrial transcript ID matching fix.
6. **[6. Downstream Analysis & COTAN Validation](file:///home/deli/athena_mount/docs/6_downstream_analysis.md)**: Outlines the application of COTAN and comparing results against SCALPEL and biological references.
7. **[7. Script & Pipeline Architecture](file:///home/deli/athena_mount/docs/7_script_architecture.md)**: Documents the system internals, process interfaces, inputs/outputs, and Nextflow DSL2 flow.

---

## 4. Configuration & Parameter Personalization

All configuration is centralized inside [nextflow.config](file:///home/deli/athena_mount/nextflow.config). For a detailed reference on all parameters, resource limits, and overrides, see [1. Configuration & Parameter Guide](file:///home/deli/athena_mount/docs/1_configuration_parameters.md).

### Personalizing alignment parameters
You can edit the `scrnaseq_params` map inside `nextflow.config` to modify `nf-core/scrnaseq` settings, or override them at run-time:
```bash
nextflow run main.nf --scrnaseq_params.skip_cellbender false
```

---

## 5. Pipeline Execution & Step-by-Step Testing

The pipeline can be executed end-to-end or step-by-step:

### A. Full Run
To execute the entire pipeline (Download -> Align -> Filter):
```bash
nextflow run main.nf \
  --dataset <dataset_name> \
  --srr_ids <srr_id_list_or_range> \
  --genome <genome_code>
```
*Example*:
```bash
nextflow run main.nf --dataset manno2021 --srr_ids SRR11947578-SRR11947580 --genome GRCm38
```

### B. Step-by-Step Run
You can use the `--step` flag to run specific components of the pipeline:
1. **Download only**:
   ```bash
   nextflow run main.nf --dataset manno2021 --srr_ids SRR11947578 --step download
   ```
2. **Alignment only** (scans existing `datasets/manno2021/` for FASTQ pairs):
   ```bash
   nextflow run main.nf --dataset manno2021 --genome GRCm38 --step align
   ```
3. **Filtering only** (runs QC filtering on existing alignment output matrix):
   ```bash
   nextflow run main.nf --dataset manno2021 --step filter
   ```

### C. Resuming Pipeline Tasks
If execution is interrupted or you make changes to parameters or R QC scripts, run with `-resume` to skip already completed processes:
```bash
nextflow run main.nf --dataset manno2021 --genome GRCm38 -resume
```
