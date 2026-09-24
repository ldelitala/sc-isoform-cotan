# 3. Data Ingestion & Storage Policy

This document describes the process of acquiring raw single-cell sequencing datasets from the NCBI Sequence Read Archive (SRA), the datasets the thesis reports on, and the storage policy for the shared server. Dataset identifiers, accessions and assemblies are listed in [`data_availability.md`](data_availability.md).

---

## 1. Data Download Scenarios

When fetching datasets using SRA SRR IDs, the project encounters two primary layouts depending on how the authors submitted the sequencing data:

### Format A: Standard Paired-End FASTQ Ingestion
* **Format**: The SRA run contains separate Read 1 (barcodes/UMIs) and Read 2 (cDNA transcript sequence) streams.
* **Execution**: Running standard `fasterq-dump --split-files` yields two files: `_1.fastq.gz` and `_2.fastq.gz`.
* **Automation**: The `DOWNLOAD_FASTQ` process runs standard `fasterq-dump` and `pigz` utilities inline. The raw SRA file is downloaded directly to the RAM disk `/dev/shm` (or task workspace), extracted, compressed, and cleaned up.

### Format B: BAM-to-FASTQ Reconstructed Ingestion
* **Format**: The authors uploaded pre-aligned Cell Ranger BAM files to SRA. Cell barcodes and UMIs are stored as metadata tags (`CB` and `UB`) instead of standard read sequence streams.
* **Issue**: Standard `fasterq-dump` only extracts the transcript sequence, producing a single `_1.fastq.gz` file and discarding the barcode/UMI tags.
* **Resolution**:
  1. Download the original BAM file format using `prefetch`:
     ```bash
     prefetch --type TenX <srr_id>
     ```
  2. Use the official 10x Genomics **`bamtofastq`** tool to convert the BAM file back to standard `_R1` (barcodes + UMIs) and `_R2` (cDNA transcripts) FASTQ files.
* **Automation**: The workflow branches dynamically based on layout results from the ENA API via `CHECK_LAYOUT`. If BAM layout, it invokes `DOWNLOAD_BAM` inline to run `prefetch` and `bamtofastq` conversions.

---

## 2. Storage Footprint & RAM-Disk Policy

Because this analysis is conducted on a **shared university server** with other users, storage consumption must be managed carefully.

* **BAM File Size**: ~18 GB per sample.
* **Zipped FASTQs Size**: ~8 GB per sample.
* **Total Storage (Both Formats)**: ~26 GB per sample.

### Storage Projections
Per sample, budget roughly ~26 GB if both formats are staged (~18 GB BAM, ~8 GB zipped FASTQ). The exact footprint on athena — where `/data` is an 18 TB array — is measured in [`athena_layout.md`](athena_layout.md).

### Policy Protocol
To minimize storage footprint and avoid disk I/O bottlenecks:
1. **Zero Persistent Spikes**: Both `DOWNLOAD_BAM` and `DOWNLOAD_FASTQ` processes are configured with scratch paths (`scratch '/dev/shm'`) to perform calculations and stage raw SRA/BAM files directly inside the RAM disk. No raw BAM or SRA files are ever written to the persistent hard drives.
2. **Immediate Conversion**: Reconstructed FASTQs are extracted and compressed inside the RAM disk before being saved to the final datasets folder via Nextflow's `storeDir`.
3. **Guaranteed Cleanup**: Nextflow's native task scratch directory cleanup ensures all temporary RAM disk files are completely wiped when tasks terminate.

---

## 3. Datasets Ingested

Two datasets produced the reported results; both are fetched through the same
`DOWNLOAD_FASTQ`/`DOWNLOAD_BAM` path. Accessions, assemblies and workspace paths
are in [`data_availability.md`](data_availability.md):

1. **Arrigoni 2023** (GEO `GSE243665`) — human lung-cancer cell lines + PBMCs,
   GRCh38, transcript level. SRA runs `SRR26127904`–`SRR26127911`.
2. **Ding cortex_2** (GEO `GSE132044`) — mouse cortex, GRCm39, gene and
transcript levels. SRA runs `SRR9170683`…`SRR9170886` (8).

Samplesheets live on athena at `work/<dataset>/pipeline/samplesheet.csv`. The other
datasets once considered for evaluation (La Manno 2021, Yuzwa 2017, Loo 2019)
were not used.
