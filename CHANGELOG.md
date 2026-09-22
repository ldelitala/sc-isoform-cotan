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

## [0.1.0] - 2026-06-19

### Added
- Nextflow pipeline: ingest → index → align (nf-core/scrnaseq + simpleaf) → QC filter.
- COTAN R layer for isoform-level co-expression, GDI, clustering, DEA and DTU candidates.
