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
├── README.md                 # Main project introduction & entry point
├── bin/                      # Custom binary scripts (automatically in PATH)
│   ├── filter_matrix.R       # QC filtering script
│   ├── lib_io.R              # R Matrix IO helper
│   └── lib_qc.R              # R QC threshold calculation helper
├── cache/                    # Local singularity download cache
├── data/                     # Central data directories
│   ├── datasets/             # Extracted fastq sequence datasets
│   ├── references/           # Genome references (FASTA, GTF sources) and indices
│   ├── unfiltered/           # Raw count matrices (valuable alignment output)
│   └── filtered/             # Cleaned QC-filtered RDS matrices (COTAN input)
├── docs/                     # Project documentation markdown guides
├── runs/                     # Execution run directory (workspace per dataset)
└── src/                      # Pipeline source code directory
    ├── nextflow.config       # Central config file (loaded automatically)
    ├── main.nf               # Parent nextflow orchestration script
    ├── modules/              # Nextflow module files (ingest, align, index, filter)
    └── scripts/              # Helper utility scripts (e.g. apply_cheat_index)
```

---

## 3. Project Documentation Index

Refer to the detailed guides in the `docs/` folder in the logical reading order:

1. **[1. Configuration & Parameter Guide](docs/1_configuration_parameters.md)**: Details all workflow parameters, QC thresholds, resource limits, and Singularity settings.
2. **[2. Cluster Resource & Thread Management](docs/2_cluster_resource_management.md)**: Explains priority scheduling (`nice`/`ionice`), memory calculations, RAM disk staging, and thread configurations.
3. **[3. Data Ingestion & Storage Policy](docs/3_data_ingestion.md)**: Details standard paired-end vs. BAM-to-FASTQ reconstructed SRA downloads and storage optimization policy.
4. **[4. Transcript-Level Quantification](docs/4_transcript_quantification.md)**: Explains the simpleaf index identity mapping cheat and Nextflow alignment run parameters.
5. **[5. Quality Control & Filtering](docs/5_qc_filtering.md)**: Details the R script filtering logic and the mitochondrial transcript ID matching fix.
6. **[6. Downstream Analysis & COTAN Validation](docs/6_downstream_analysis.md)**: Outlines the application of COTAN and comparing results against SCALPEL and biological references.
7. **[7. Script & Pipeline Architecture](docs/7_script_architecture.md)**: Documents the system internals, process interfaces, inputs/outputs, and Nextflow DSL2 flow.

---

## 4. Configuration & Portability Personalization

All configuration is centralized inside `src/nextflow.config`. For a detailed reference on parameters and limits, see [1. Configuration & Parameter Guide](docs/1_configuration_parameters.md).

### Portability & Centralization Overrides (Option B)
To manage a centralized data setup without editing repository configuration files:
1. Copy the template file: `cp central.config.example central.config`
2. Open `central.config` and customize the absolute paths to point to your centralized storage.
3. Run Nextflow with the `-c` config flag:
   ```bash
   nextflow run ../../src/main.nf -c central.config --dataset arrigoni2023 --genome GRCh38
   ```

### Dynamic Genomes Reference Resolution
If a genome is not cataloged in `src/conf/genomes.config`, resolve it dynamically by providing the Ensembl species name and assembly code:
```bash
nextflow run ../../src/main.nf \
  --dataset cerevisiae_run \
  --genome R64-1-1 \
  --genome_species saccharomyces_cerevisiae \
  --genome_assembly R64-1-1
```
The pipeline automatically formats Ensembl URLs, downloads the FASTA/GTF files (supporting fallback to toplevel if primary assembly is not found), and indexes the genome.

---

## 5. Pipeline Execution (Highly Portable Runs)

To ensure run isolation and keep the codebase clean, the pipeline is designed to be executed inside dedicated run workspaces.

### Step 1: Initialize the run directory
Create a run folder inside `runs/` (or anywhere else) and navigate into it:
```bash
mkdir -p runs/arrigoni2023_try1
cd runs/arrigoni2023_try1
```

### Step 2: Launch the pipeline
Run Nextflow from inside the workspace referencing the pipeline script (e.g. `../../src/main.nf`). This automatically places Nextflow log files, intermediate `.nextflow` caching, and parent `work/` directories inside the workspace:

#### A. Execute Remote Pipeline (No manual clone needed)
Nextflow supports executing the pipeline directly from a remote GitHub repository. Nextflow will download, cache, and run it automatically:
```bash
nextflow run username/sc-isoform-pipeline \
  -profile singularity \
  --dataset arrigoni2023 \
  --srr_ids SRR26127904 \
  --genome GRCh38
```

#### B. Execute Local Pipeline
```bash
nextflow run ../../src/main.nf \
  -profile singularity \
  --dataset arrigoni2023 \
  --srr_ids SRR26127904 \
  --genome GRCh38
```

#### C. Execute with Direct Dataset Directory (Auto-extract dataset name)
If you already have sequence files in a specific folder, pass `--dataset_dir` instead of `--dataset`:
```bash
nextflow run ../../src/main.nf \
  -profile singularity \
  --dataset_dir /home/deli/athena_mount/data/datasets/arrigoni2023 \
  --genome GRCh38
```
This will automatically detect the dataset name as `arrigoni2023` and save output matrices using that name.

### Step 3: Run Step-by-Step or Resume
Use the `--step` flag to run specific tasks (`all`, `download`, `align`, `filter`), or append `-resume` to restart from the last checkpoint:
```bash
nextflow run ../../src/main.nf -profile singularity --dataset arrigoni2023 --genome GRCh38 -resume
```
