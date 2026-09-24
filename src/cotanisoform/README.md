# `src/cotanisoform/` — the R package

The toolbox every analysis step is built from. It adapts
[COTAN](https://github.com/seriph78/COTAN) co-expression and zero-count
statistics from gene level to transcript (isoform) level, and provides the
Seurat clean-up and the structured workflow logging that the drivers use.

The package is **not** an end-to-end pipeline. The end-to-end, config-driven
usage lives in [`../analysis/README.md`](../analysis/README.md); this file
documents the package itself. Full reference: the roxygen-generated
`man/*.Rd` (one page per function).

## Install

COTAN itself is deliberately **not** a conda package — the commit is the
reproducibility-critical part. `scripts/install_deps.R` installs it from the
pinned commit `be93aa8` (version 2.13.1) and asserts the version. Then install
this package:

```bash
conda activate cotanisoform-analysis
Rscript scripts/install_deps.R     # COTAN 2.13.1 @ be93aa8
R CMD INSTALL src/cotanisoform
```

The package is `R CMD check` clean (no errors, warnings or notes) on a **built
tarball** — see `CONTRIBUTING.md` for the recipe.

## What it exports

39 exported functions in two groups.

### Per-stage analysis functions

Each maps to one stage of the analysis driver (`src/analysis/R/0X_*.R`):

| Group | Functions |
| :--- | :--- |
| Seurat clean-up (`20_seurat.R`) | `clean_simpleaf_barcodes`, `round_seurat_counts`, `filter_empty_droplets`, `filter_spliced_transcripts`, `filter_mt_transcripts`, `filter_iterative_sparsity`, `create_test_subset` |
| COTAN construction (`30_cotan_init.R`) | `initialize_cotan_from_seurat`, `clean_cotan_data`, `filter_cotan_by_condition` |
| Cell/gene/cluster metadata (`31_cotan_metadata.R`) | `update_cell_condition`, `add_origin_samples`, `flag_valid_cells_from_tsv`, `add_genes_metadata`, `add_gene_info_from_t2g`, `update_cell_clusterization`, `add_cell_types_from_tsv` |
| COEX / p-values (`32_coex.R`) | `prepare_to_coex`, `calculate_coex`, `calculate_p_value` |
| GDI / clustering (`33_clustering.R`) | `calculate_gdi`, `perform_clustering` |
| Differential expression (`34_dea.R`) | `dea_on_clusters` |
| DTU extraction (`35_dtu.R`) | `extract_dtu_candidates` |
| Utils (`00_utils.R`) | `save_object`, `get_uniform_vector`, `get_mapping_vector` |

### Logging layer (`10_logging.R`)

Structured, tree-shaped console/file logging with an indentation stack and a
theme:

`reset_log_state`, `set_log_theme`, `config_workflow`, `log_header`,
`log_info`, `log_warn`, `log_error`, `log_stat`, `log_debug`,
`log_estimator_stats`, `log_matrix_stats`, `log_cotan_execution`.

## A minimal worked example

Illustrative chain for one COTAN object, transcript level (the exact parameters
for a dataset live in the config, not here):

```r
library(cotanisoform)

obj <- initialize_cotan_from_seurat(seurat_obj, geo_id = "GSE243665",
                                    seq_method = "10xv1", condition = "Transcript")
obj <- clean_cotan_data(obj)
obj <- prepare_to_coex(obj)          # lambda / nu / dispersion
obj <- calculate_coex(obj)
obj <- calculate_p_value(obj)
obj <- calculate_gdi(obj)
obj <- perform_clustering(obj)
obj <- dea_on_clusters(obj)
res <- extract_dtu_candidates(obj, clusterization_name = "Known_Cell_Types",
                              p_value_threshold = 0.05, min_dea_contrast = 0.2)
```

Each `*_cotan` function accepts optional `output_dir`/`file_name` arguments and
saves the object with `save_object()`, so the chain can be checkpointed between
the expensive steps. `extract_dtu_candidates()` returns the candidate table and
writes one CSV/RDS per call.
