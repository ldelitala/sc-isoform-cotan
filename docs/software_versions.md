# Software versions

What the published results were produced with. The **load-bearing pins** are the
R version, the COTAN commit and the container tags; other R packages float with
current repodata unless pinned (see the caveat at the end).

## R environment (`envs/analysis.yml`, conda env `cotanisoform-analysis`)

Measured in the `deli` env on 2026-09-22.

| Package | Version |
| :--- | :--- |
| R | **4.5.3** (2026-03-11) |
| COTAN | **2.13.1** — `seriph78/COTAN` @ **`be93aa8`** |
| Seurat | 5.5.1 |
| SeuratObject | 5.4.0 |
| Matrix | 1.7.5 |
| ggplot2 | 4.0.3 |
| mclust | 6.1.3 |
| conflicted | 1.2.0 |
| devtools | 2.5.2 |
| roxygen2 | 8.0.0 |
| testthat | 3.3.2 |
| lintr | 3.3.0-1 |
| styler | 1.11.0 |

COTAN is deliberately **not** a conda package: `scripts/install_deps.R` installs it
from the pinned commit `be93aa8` and asserts the version is `2.13.1`.

## Pipeline launcher (`envs/pipeline.yml`)

| Tool | Version |
| :--- | :--- |
| Nextflow | **26.04.4** |
| OpenJDK | 21 |
| pigz | (conda-forge current) |

## Alignment (Singularity containers)

| Tool | Version |
| :--- | :--- |
| simpleaf (index build) | `0.24.0--hd612981_1` |
| simpleaf (align / quant) | `0.24.1--hd612981_0` |
| nf-core/scrnaseq | **4.1.0** |
| Ensembl reference release | **102** |

Tags are hard-coded in `src/pipeline/modules/index.nf` and
`src/pipeline/modules/align.nf`. `nf-core/scrnaseq` is launched as a child run
with `NXF_SYNTAX_PARSER=v1`.

## Caveat

`r-base`, the COTAN commit and the container tags are the pins that matter. Other
R package versions float with current conda repodata: a fresh solve may pick
`r-matrix`, `r-roxygen2` or `r-lintr` at a newer version than the table above (the
original env had `matrix` 1.7_5, `roxygen2` 8.0.0, `lintr` 3.3.0). Pin those too
if byte-exact reproduction of the code (not the results) is ever required. The
results themselves are fixed by the stored objects and checked by
`scripts/verify_dtu_parity.R`.
