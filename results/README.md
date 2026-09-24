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

Each dataset dir has the same shape: `tables/` (the thesis deliverables), `plots/`, `logs/`.

## What each dataset dir contains

- `tables/dtu_candidates*.csv` / `.rds` — DTU candidate tables (the thesis deliverable).
  arrigoni writes `dtu_candidates.csv`; ding cortex_2 writes
  `dtu_candidates.gene_cluster.csv` and `dtu_candidates.transcript_cluster.csv`.
- `tables/dtu_shared.csv` (39 rows), `dtu_exclusive_file1.csv` (3), `dtu_exclusive_file2.csv` (4)
  — the **released** gene-vs-transcript DTU comparison of 2026-07-24, kept because the
  thesis appendix tables are built from it. Step `08_compare_dtu.R` on the final 46/46
  tables yields 45 / 1 + 1, so re-running that step does not reproduce these files; see
  [`../docs/dtu_methods.md`](../docs/dtu_methods.md).
- `plots/` — COTAN diagnostics: GDI plots, UMAPs, cluster/dendrogram plots. Includes
  the `*_tau_sweep.{csv,png}` contrast-threshold sensitivity sweep (step `09_sweep_tau.R`;
  the copies here were produced by the earlier standalone script and moved from `work/`).
- `logs/` — per-step run logs (`init_cotan`, `cotan_calc`, `cluster`, `plot_gdi`, …).
- `tables/t2gene_name.tsv`, `tables/GSE243665_combined_QC_barcodes.tsv` — feature/barcode maps.

## Excluded (remain on Athena under `/data/lorenzo_delitala`)

Large intermediate objects: `calculated.*.cotan.rds` (~3–5.5 GB),
`clustered.*.rds` (~1–3 GB), `raw_matrix.seurat.rds` (~0.2–2.5 GB),
`ready_to_coex.seurat.rds` (676 MB), plus all raw data (`data/inputs/fastqs`,
`data/inputs/reference`, `data/built/`) and computed work trees (`work/`).

## Provenance

Produced on Athena by the `src/analysis/` driver steps (`src/analysis/run_all.R`) using the
`src/cotanisoform` R package. Files were copied verbatim; no post-processing.

## Refreshing

```bash
# on Athena
./scripts/collect_results.sh                 # stages scratch/publish_results (gitignored)
# on the Mac
rsync -a athena:/data/lorenzo_delitala/scratch/publish_results/ results/
git add results && git commit -m "Update results"
git push github HEAD    # push the branch you are working on
```
