# 3. Data Ingestion & Storage Policy

This document describes the process of acquiring raw single-cell sequencing datasets from the NCBI Sequence Read Archive (SRA), the target datasets for the thesis, and the storage policy for the shared server.

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

### Storage Projections (500 Samples across 10 Datasets)
* **FASTQs only (Zipped)**: **~4.0 TB** (Safe and polite storage usage).
* **BAMs + FASTQs**: **~13.0 TB** (Risky; will fill the 14TB disk and cause system warnings).

### Policy Protocol
To minimize storage footprint and avoid disk I/O bottlenecks:
1. **Zero Persistent Spikes**: Both `DOWNLOAD_BAM` and `DOWNLOAD_FASTQ` processes are configured with scratch paths (`scratch '/dev/shm'`) to perform calculations and stage raw SRA/BAM files directly inside the RAM disk. No raw BAM or SRA files are ever written to the persistent hard drives.
2. **Immediate Conversion**: Reconstructed FASTQs are extracted and compressed inside the RAM disk before being saved to the final datasets folder via Nextflow's `storeDir`.
3. **Guaranteed Cleanup**: Nextflow's native task scratch directory cleanup ensures all temporary RAM disk files are completely wiped when tasks terminate.

---

## 3. Target Datasets Checklist

Based on the [COTAN Datasets Analysis Index](https://seriph78.github.io/COTAN_Datasets_analysis/), the following single-cell datasets are targeted to evaluate isoform-aware expression mapping:

1. **Mouse Brain (La Manno 2021)**:
   * **Tissue**: ForebrainDorsal (E13.5)
   * **SRR IDs**: `SRR11947578` to `SRR11947627`
2. **Mouse Cortex (Yuzwa 2017)**:
   * **Ages**: E13.5 and E17.5
   * **SRR IDs**: `GSM2861511`, `GSM2861514` (SRA counterparts)
3. **Mouse Cortex (Loo 2019)**:
   * **Age**: E14.5
4. **Arrigoni 2023 / Morabito 2021**:
   * Comparative controls for pipeline testing.
