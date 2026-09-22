# Results

Curated, small analysis outputs from the sc-Isoform COTAN runs on Athena. The
multi-GB intermediate objects (COTAN/Seurat `.rds` matrices) are **not** here —
they are Git-unfriendly and stay on the machine.

## Datasets

| Dir | Dataset | Level |
| :--- | :--- | :--- |
| `arrigoni/` | Arrigoni 2023 (GSE243665), human cell lines | transcript (isoform) |
| `ding_cortex_2/` | Ding mouse cortex | gene vs transcript comparison |
| `gdi_distribution.pdf` | scratch/test run | transcript |

## What each dataset dir contains

- `dtu_candidates*.csv` / `.rds` — DTU candidate tables (the thesis deliverable).
- `dtu_shared.csv`, `dtu_exclusive_file*.csv` — gene-vs-transcript DTU comparison.
- `plots/` — COTAN diagnostics: GDI plots, UMAPs, cluster/dendrogram plots.
- `logs/` — per-step run logs (`init_cotan`, `cotan_calc`, `cluster`, `plot_gdi`, …).
- `Rscripts/` — the analysis scripts that produced these outputs (`gene/`, `transcript/`).
- `t2gene_name.tsv`, `GSE243665_combined_QC_barcodes.tsv` — feature/barcode maps.

## Excluded (remain on Athena under `/data/lorenzo_delitala`)

Large intermediate objects: `calculated.*.cotan.rds` (~3–5.5 GB),
`clustered.*.rds` (~1–3 GB), `raw_matrix.seurat.rds` (~0.2–2.5 GB),
`ready_to_coex.seurat.rds` (676 MB), plus all raw data (`data/fastqs`,
`data/genomes`) and Nextflow run trees (`runs/`).

## Provenance

Produced on Athena by the R analysis layer in `src/libs/` (see the repository
`README.md`). Files were copied verbatim; no post-processing.
