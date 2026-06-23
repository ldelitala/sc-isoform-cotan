# 1. Configuration & Parameter Guide

This document provides a detailed reference for all configuration options, quality control thresholds, and resource limits defined in [nextflow.config](../nextflow.config).

---

## 1. Core Workflow Parameters
These options dictate the datasets, references, and pipeline execution steps.

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `params.dataset_dir` | `String` | `""` | Direct path to the dataset folder containing the FASTQ sequence files. The basename of this folder is dynamically resolved as the dataset identifier. |
| `params.srr_ids` | `String` | `""` | Comma-separated list (e.g. `SRR01,SRR02`) or range (e.g. `SRR11947578-SRR11947627`) of SRA run IDs to download. |
| `params.genome` | `String` | `""` | Genome assembly code (e.g. `GRCm38` or `GRCh38`). Nextflow uses this to locate the index under `${params.index_dir}/${genome}_simpleaf`. |
| `params.simpleaf_index` | `String` | `""` | Path to a pre-built simpleaf index folder. Overrides `index_dir` lookup and skips automated index building. |
| `params.transcript_level` | `Boolean` | `true` | True to run with transcript-level (isoform-aware) identity mapping cheat, false for standard gene-level alignment. |
| `params.step` | `String` | `"all"` | Pipeline execution mode. Options:<br>• `"all"`: Runs ingestion, alignment, and filtering.<br>• `"download"`: Runs SRA prefetch and extraction only.<br>• `"align"`: Scans existing FASTQs and aligns.<br>• `"filter"`: Runs R QC filtering on existing raw RDS matrix. |
| `params.webhook_url` | `String` | `secrets.WEBHOOK_URL` | Target Discord/Slack webhook URL to post progress alerts and failure reports (secured via Nextflow Secrets). |

---

## 2. Nested `nf-core/scrnaseq` Parameters Map
These settings configure the downstream `nf-core/scrnaseq` simpleaf alignment run.

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `protocol` | `"10XV3"` | Sequencing chemistry version (e.g. `10XV2` or `10XV3`). |
| `skip_cellbender` | `true` | Skips CellBender ambient RNA background noise correction (runs standard raw simpleaf mapping). |
| `simpleaf_umi_resolution` | `"parsimony-em"` | Alevin UMI resolution algorithm. Optimized for handling multi-mapping reads at the transcript level. |

*Note: You can pass overrides at run time: `--scrnaseq_params.protocol 10XV2`.*

---

## 3. Quality Control & Filtering Thresholds
These parameters configure the cell-level quality control filters executed by R.

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `params.min_features` | `Integer` | `200` | Minimum number of unique transcripts/genes detected per cell. Filters out empty droplets or failed cells. |
| `params.max_features` | `Integer` | `8000` | Maximum number of unique transcripts/genes detected per cell. Filters out doublets (droplets containing multiple cells). |
| `params.min_counts` | `Integer` | `500` | Minimum total UMI count detected per cell. |
| `params.max_percent_mt`| `Double` | `10.0` | Maximum allowed percentage of reads mapping to mitochondrial transcripts. High MT ratio indicates cell stress/apoptosis. |
| `params.mt_transcripts`| `String` | `"config/mt_transcripts.txt"` | Path to a text file containing Ensembl Transcript IDs for mitochondrial genes (used to perform transcript-level filtering). |

---

## 4. Hardware Resources & Priority Controls
These options manage thread allocations and priorities to maintain server speed on shared hardware.

### Global Engine Scheduling
* `executor.cpus = 80`: Hard upper limit of CPU cores Nextflow can manage.
* `executor.memory = '2.5 TB'`: Hard upper limit of RAM Nextflow can request.
* `process.beforeScript = 'nice -n 19 ionice -c 3'`: Systematically wraps all shell executions with lowest CPU scheduling priority (niceness 19) and idle disk read/write priority class.

### Process Concurrency Constraints
Nextflow limits concurrently running tasks and allocated threads dynamically to prevent server lockups:

* **`DOWNLOAD_BAM` & `DOWNLOAD_FASTQ`**:
  * `maxForks = 6`: Restricts parallel SRA downloads to 6 accessions (replaces `MAX_PARALLEL_JOBS` from `.env`).
  * `cpus = 12`: Number of threads allocated per SRA extraction (fasterq-dump and pigz parallel compression).
* **`ALIGN_SIMPLEAF`**:
  * Runs natively via an `exec:` block on the head node, bypassing standard task scheduling queues. Limits are directly defined and passed to the child process command line (`--max_cpus 72 --max_memory '2 TB'`).
* **`QC_FILTER`**:
  * `cpus = 8`: Multi-threaded matrix reads mapping.
  * `memory = '100 GB'`: Memory ceiling to load large expression datasets.

---

## 5. Project Directory & Reference Path Parameters
These parameters centralize the project's folder layout and automate reference genome downloads:

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `params.dataset_dir` | `String` | `"${launchDir}/data/dataset"` | Raw FASTQ input directory. Folder basename is dynamically resolved as the dataset name. |
| `params.reference_dir` | `String` | `"${launchDir}/data/reference"` | Root folder containing genome reference source files (FASTAs, GTFs). |
| `params.index_dir` | `String` | `"${launchDir}/data/index"` | Root folder containing built simpleaf index files. |
| `params.preprocessing_dir` | `String` | `"${launchDir}/preprocessing"` | Execution directory for child pipeline (nf-core/scrnaseq) run. |
| `params.unfiltered_dir` | `String` | `"${launchDir}/data/unfiltered"` | Target directory where raw count matrices are stored. |
| `params.filtered_dir` | `String` | `"${launchDir}/data/filtered"` | Target directory where QC-filtered RDS matrices are written, ready for COTAN. |
| `params.genome_species` | `String` | `""` | Ensembl species identifier for dynamic genome download (e.g. `homo_sapiens`). |
| `params.genome_assembly` | `String` | `""` | Ensembl assembly identifier for dynamic genome download (e.g. `GRCh38`). |
| `params.ensembl_release` | `Integer` | `102` | Ensembl release number used to compile references (defined in `genomes.config`). |
| `params.reference_urls` | `Map` | *(Map)* | Configuration map matching genome codes to Ensembl primary assembly FASTA and GTF URLs (defined in `genomes.config`). |
