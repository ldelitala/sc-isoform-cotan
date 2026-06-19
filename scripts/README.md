# Scripts Directory

This directory contains automation scripts to download data, run the processing pipeline, and filter raw matrices.

## Workflow

The automated process consists of three steps:

### Step 1: Download Datasets
Use `stage1_download/download_data.sh` to download raw FASTQ files from SRA. You can download a single accession or a consecutive range of accessions in parallel.
```bash
# Single accession:
./scripts/stage1_download/download_data.sh <dataset_name> <accession>
# Example:
./scripts/stage1_download/download_data.sh Arrigoni2023 SRR26127910

# Range of accessions:
./scripts/stage1_download/download_data.sh <dataset_name> <start_accession> <end_accession>
# Example:
./scripts/stage1_download/download_data.sh Arrigoni2023 SRR26127904 SRR26127911
```
This automatically maps each SRA to a sample directory named after its last 2 digits:
`datasets/<dataset_name>/<last_two_digits_of_accession>/`

**High-Performance Features (Optimized for Shared Clusters)**:
- **Parallel downloads**: Runs up to 6 accessions concurrently (`MAX_PARALLEL_JOBS=6`).
- **RAM temp storage**: Uses `/dev/shm` (Linux RAM disk) for `fasterq-dump` temp files, bypassing hard drive speed bottlenecks.
- **Polite CPU usage**: All extraction and compression tasks are ran with `nice -n 19` to yield CPU cycles to other cluster users automatically.

---

### Step 2: Generate Raw Matrix (Nextflow)
Use `stage2_align/run_pipeline.sh` to run the nf-core/scrnaseq simpleaf pipeline on all downloaded samples of a dataset at once.
```bash
./scripts/stage2_align/run_pipeline.sh <dataset_name> <genome_code> <protocol>
# Example:
./scripts/stage2_align/run_pipeline.sh Arrigoni2023 GRCh38 10XV3
```
This automatically scans `datasets/<dataset_name>/` to build a multi-sample `input.csv` file, writes the execution configuration, and runs Nextflow inside a dedicated directory:
`runs/<dataset_name_lowercase>_pipe1/`

**Pipeline Features**:
- **Automatic cleanup**: Deletes the intermediate `work/` folder (saving 100+ GB) immediately upon successful execution.
- **Troubleshooting**: If execution fails, `work/` is preserved so you can resume the run.
- **Thesis metrics**: Outputs HTML timeline charts and resource usage logs to `results/pipeline_info/`.

Raw matrix results are saved in:
`runs/<run_name>/results/simpleaf/homo/simpleaf_quant/af_quant/alevin/`

---

### Step 3: Apply Filters (R)

Use the updated `filter_matrix.R` script to apply QC thresholds. It supports both raw nested directories and combined RDS files, automatically detecting the format.

#### File Structure
* **`scripts/stage3_filter/filter_matrix.R`**: Main entry runner.
* **`scripts/stage3_filter/lib_io.R`**: Input/Output library. Can extract counts from Seurat/SCE objects even if those packages are not installed (using direct base R slot extraction fallbacks).
* **`scripts/stage3_filter/lib_qc.R`**: Quality control calculation and cell filtering library.

#### Examples

##### Case A: Filter Raw Matrix (Single or Combined Multiple Samples)
Pass a parent folder (e.g. `results/simpleaf/`) containing one or more sample folders. The script automatically merges them column-wise, prefixes cell barcodes with the sample name to prevent collision, filters the merged matrix, and saves a single RDS file:
```bash
Rscript ./scripts/stage3_filter/filter_matrix.R \
  --input_path runs/arrigoni2023_pipe1/results/simpleaf/ \
  --output_dir filtered/ \
  --sample_name arrigoni2023_pipe1_combined
```

##### Case B: Filter Nextflow's Combined RDS File (Seurat format)
Filter the pipeline's combined Seurat object directly:
```bash
Rscript ./scripts/stage3_filter/filter_matrix.R \
  --input_path runs/arrigoni2023_pipe1/results/simpleaf/mtx_conversions/combined_raw_matrix.seurat.rds \
  --output_dir filtered/ \
  --sample_name arrigoni2023_pipe1_filtered
```

##### Case C: Filter Nextflow's Combined RDS File (SCE format)
Filter the pipeline's combined SingleCellExperiment object directly:
```bash
Rscript ./scripts/stage3_filter/filter_matrix.R \
  --input_path runs/arrigoni2023_pipe1/results/simpleaf/mtx_conversions/combined_raw_matrix.sce.rds \
  --output_dir filtered/ \
  --sample_name arrigoni2023_pipe1_filtered
```

#### Outputs
The script filters out low-quality cells and saves:
* `filtered/<sample_name>_filtered.rds` (Standard R list structure containing `matrix` and `metadata` data frame)

