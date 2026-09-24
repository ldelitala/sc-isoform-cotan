# Data availability

The two datasets the thesis reports on, the public sources they come from, and
how to re-download them. The processed objects themselves are **not** in the
repository (multi-GB); they live on athena under `work/<dataset>/analysis/`.

## Arrigoni 2023 — human lung-cancer cell lines

| | |
| :--- | :--- |
| GEO | **GSE243665** |
| Organism / assembly | *Homo sapiens*, **GRCh38** (Ensembl release 102) |
| Assay | 10x Chromium, `10xv1` |
| Samples | 8: A549, CCL-185-IG, CRL5868, DV90, HCC78, HTB178, PBMCs, PC9 |
| Level used | transcript (isoform) |
| SRA runs (ingested) | `SRR26127904`–`SRR26127911` (8) |
| Samplesheet | `athena:work/arrigoni/pipeline/samplesheet.csv` (sample `banchmark_mix`) |
| Analysis workspace | `athena:work/arrigoni/analysis/` |

This is a benchmark mixture of eight cell lines labelled by GEO barcode files;
those same barcodes are the `Known_Cell_Types` clusterization used for DEA.

## Ding cortex_2 — mouse cortex

| | |
| :--- | :--- |
| GEO | **GSE132044** |
| Organism / assembly | *Mus musculus*, **GRCm39** (Ensembl release 102) |
| Assay | 10x Chromium v2, `10XV2` ("Cortex2" cells) |
| Level used | gene **and** transcript (compared) |
| SRA runs (ingested) | `SRR9170683`, `SRR9170684`, `SRR9170686`, `SRR9170687`, `SRR9170691`, `SRR9170692`, `SRR9170693`, `SRR9170886` (8) |
| Samplesheet | `athena:work/ding_cortex_2/pipeline/samplesheet.csv` (sample `cortex_2`) |
| Analysis workspace | `athena:work/ding_cortex_2/analysis/` |

The cortex run is the gene-vs-transcript comparison: the same cells are analysed
at both levels and the DTU candidate tables are intersected (step `08`). The
cortex_2 cells arrive already QC-filtered; the barcode list is
`inputs/geo_metadata/ding_cortex_2/clean_Cortex2_QC_barcodes.tsv.gz`.

Two further Ding runs (`brain1`, `pbmc1`) were completed but produced no reported
table; both were removed before submission (2026-09-22).

## Re-downloading

Everything is fetched from public sources by the Nextflow half. On athena, from
inside a run directory (`work/` is gitignored and exists only there):

```bash
cd /data/lorenzo_delitala/work/<dataset>/pipeline
./run_pipeline.sh          # nextflow run .../src/pipeline/main.nf -c nextflow.config \
                           #   -profile singularity -resume
```

This re-downloads SRA runs from NCBI/ENA, builds the simpleaf index from Ensembl
release 102 FASTA/GTF, aligns with `nf-core/scrnaseq` 4.1.0, and QC-filters.
See [`reproducibility.md`](reproducibility.md) and
[`athena_layout.md`](athena_layout.md).

## Reference policy

Third-party papers and documentation are **cited, not redistributed**. The COTAN
paper and its full documentation are therefore **not** shipped in this
repository — only referenced. (The thesis repository follows the same rule and
gitignores its `docs/COTAN_*.pdf` copies.) CITATION.cff entry for this
repository: see [`../CITATION.cff`](../CITATION.cff).

Primary reference for COTAN: the COTAN paper and the package at
<https://github.com/seriph78/COTAN> (commit `be93aa8`, v2.13.1 — the version the
published results were produced with).
