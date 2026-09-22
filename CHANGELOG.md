# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `envs/` (analysis + pipeline conda definitions) and `scripts/install_deps.R` pinning COTAN.
- DTU parity harness `scripts/verify_dtu_parity.R` (3/3 published cases reproduced).

### Changed
- Merged ten R packages (`project.*`, `deli.*`) into a single package, `cotanisoform/`.
- Moved the downstream drivers into a config-driven `analysis/` layer; no hardcoded paths.
- Curated published outputs live under `results/`.

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
