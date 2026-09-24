# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- Moved `cotanisoform/` and `analysis/` under `src/` (`src/cotanisoform/`, `src/analysis/`);
  all references (README, docs, CI, lintr, CONTRIBUTING) updated to the new paths.

### Added
- Step `09_sweep_tau.R` in `src/analysis/`: config-driven `tau` (`min_dea_contrast`)
  sensitivity sweep reusing the stored COTAN objects and cached DEA/p-values.

### Removed
- `scripts/sweep_tau.R` standalone script — superseded by step `09_sweep_tau.R`.

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
