# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- Moved `cotanisoform/` and `analysis/` under `src/` (`src/cotanisoform/`, `src/analysis/`);
  all references (README, docs, CI, lintr, CONTRIBUTING) updated to the new paths.
- Restructured the athena data tree by provenance: `data/` + `runs/` → `inputs/`
  (downloaded), `built/` (indices made from `inputs/reference`), and
  `work/<dataset>/{pipeline,analysis}/` (computed). Dataset names unified to
  `ding_cortex_2`. Configs, `verify_dtu_parity.R`, `collect_results.sh` and `.gitignore`
  updated.
- Refined the layout: `inputs/`+`built/` → `data/inputs/`+`data/built/` (work separated);
  `work/<dataset>/analysis/` grouped into `objects/ plots/ logs/ tables/` with the
  handoff `raw_matrix.seurat.rds` at the root; `results/<dataset>/` reshaped to
  `tables/ plots/ logs/`.
- Removed the duplicate `combined_raw_matrix.seurat.rds` (and unused `.h5ad`/`.sce.rds`)
  under the Nextflow `mtx_conversions/` (~33G) after checksum-verifying it against the
  pipeline handoff, plus the superseded `work/**/Rscripts/` snapshots and the contents
  of `scratch/`.

### Added
- Step `09_sweep_tau.R` in `src/analysis/`: config-driven `tau` (`min_dea_contrast`)
  sensitivity sweep reusing the stored COTAN objects and cached DEA/p-values.

### Removed
- `scripts/sweep_tau.R` standalone script — superseded by step `09_sweep_tau.R`.
- `data/test/cotan_coex.rds` (2.78 GB, not a parity input) and the duplicate
  `data/test/gdi_distribution.pdf`; `b2sample.tsv` moved to `scratch/`.

## [0.2.0] - 2026-09-22

### Added
- `envs/` (analysis + pipeline conda definitions) and `scripts/install_deps.R` pinning COTAN.
- DTU parity harness `scripts/verify_dtu_parity.R` (3/3 published cases reproduced).

### Changed
- Merged ten R packages (`project.*`, `deli.*`) into a single package, `cotanisoform/`.
- Moved the downstream drivers into a config-driven `analysis/` layer; no hardcoded paths.
- Curated published outputs live under `results/`.
- `cotanisoform` 0.2.0 is `R CMD check` clean: non-ASCII log glyphs escaped, undocumented
  `@param`s documented, unused `parallelly` / `zeallot` imports dropped, `stats::median`
  qualified. `roxygenise()` is now idempotent.

### Removed
- The ten superseded R packages (`project.*`, `deli.*`) and the two third-party COTAN
  PDFs (`COTAN_full_doc.pdf`, `COTAN_paper_v2.pdf`).
- Dead config (`central.config.example`, `src/scripts/install_cotan.R`) and the scratch
  drivers (`src/tmp*.R`, `src/clean.R`).
- The duplicated `results/**/Rscripts/` snapshots — `analysis/` is now the only driver
  layer. The two unused DTU implementations were moved to `analysis/deprecated/` first.

## [0.1.0] - 2026-06-19

### Added
- Nextflow pipeline: ingest → index → align (nf-core/scrnaseq + simpleaf) → QC filter.
- COTAN R layer for isoform-level co-expression, GDI, clustering, DEA and DTU candidates.
