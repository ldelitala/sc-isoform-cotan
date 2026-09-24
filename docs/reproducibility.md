# Reproducibility

How to recreate the reported results from scratch, and which objects let you skip
the expensive parts. Everything heavy runs on athena.

## 0. Environment

```bash
conda env create -f envs/analysis.yml      # R 4.5.3 + R libraries
conda env create -f envs/pipeline.yml      # Nextflow launcher + JDK + pigz

conda activate cotanisoform-analysis
Rscript scripts/install_deps.R             # COTAN 2.13.1 @ be93aa8
R CMD INSTALL src/cotanisoform
```

Pinned versions: [`software_versions.md`](software_versions.md).

## 1. Nextflow half — filtered matrices

On athena, one run per dataset. The script must be launched **from inside the run
directory** so `launchDir` resolves the output paths:

```bash
cd /data/lorenzo_delitala/runs/arrigoni
./run_pipeline.sh          # -> nextflow run /data/lorenzo_delitala/src/pipeline/main.nf \
                           #      -c nextflow.config -profile singularity -resume
```

Repeat for `runs/ding/cortex_2`. `--step align` (the default) downloads, builds the
index, aligns with `nf-core/scrnaseq` 4.1.0, and QC-filters. Bulk data lands under
`runs/<dataset>/results/`; the handoff Seurat object is copied to
`data/project_files/<dataset>/raw_matrix.seurat.rds`.

Datasets, accessions and assemblies: [`data_availability.md`](data_availability.md).

## 2. Analysis half — DTU candidates

From the repository root (`/data/lorenzo_delitala/src`), with `cotanisoform`
installed:

```bash
Rscript src/analysis/run_all.R --config src/analysis/config/arrigoni.yaml
Rscript src/analysis/run_all.R --config src/analysis/config/ding_cortex_2.transcript.yaml
Rscript src/analysis/run_all.R --config src/analysis/config/ding_cortex_2.gene.yaml
```

Or one step at a time, e.g. `Rscript src/analysis/R/07_dtu.R --config src/analysis/config/arrigoni.yaml`.

Options: `--root DIR` (override the config's machine root), `--out-dir DIR` (write
outputs and log to `DIR`; also **shadows inputs**, so a re-run never overwrites the
published objects), `--dry-run` (resolve and print every path, compute nothing).
`run_all.R` also takes `--from NN` / `--to NN`.

| Dataset / level | `run:` steps |
| :--- | :--- |
| arrigoni (transcript) | `00 01 02 03 04 05 07` |
| ding cortex_2 (transcript) | `00 01 02 03 04 05 06 07 08` |
| ding cortex_2 (gene) | `02 03 04 05` |

The gene-level run exists for one reason: its `local_gene_cluster` labels are
transferred onto the transcript object by step `06` of the transcript config, so
gene-level and transcript-level DTU candidates can be compared. It starts from the
GEO count matrix (`input_matrix`), not a Seurat object, and has no DTU step of its
own.

## 3. Where outputs land

Per dataset, under the config's `paths:` (`data/project_files/<dataset>/`):
`objects/` (chained `.rds`), `plots/` (GDI, UMAP, cluster), `logs/`
(`<step>.<level>.log`), and the DTU CSVs. `scripts/collect_results.sh` stages the
curated subset into `results/` (tracked).

## 4. Skipping expensive steps

Only step `07_dtu.R` produces the reported tables. The rest are upstream.

- **`03_calc`** (COEX) costs hours. If `objects.calculated` already exists, skip it:
  `run_all.R --from 04`, or run `07_dtu.R` directly.
- **`05_cluster`** is a guided optimisation whose outcome is not fixed in advance.
- The stored final COTAN object is `data/test/cotan_coex.rds` (2.78 GB) — **never
  delete it**. It is **not** an input to the parity check (`verify_dtu_parity.R`
  reads the per-dataset objects below); it is kept as the last checkpoint of the
  coexistence state.

### Parity check

```bash
Rscript scripts/verify_dtu_parity.R
```

On athena, against the stored objects, this must print
`3/3 cases reproduced exactly` and exit 0. Two of the three published tables
reproduce byte-identically; the third matches in value (it was re-serialised
unquoted after production).

## Known limitations

- Steps `01`–`06` are faithful transcriptions of the released drivers but have
  **not** been re-executed (hours of COEX, plus an undefined optimisation); they
  are validated with `--dry-run` only. Step `08` on the final tables gives
  45 shared / 1 + 1 exclusive, whereas the released `dtu_shared.csv` (39 / 3 / 4) came
  from an earlier 40/38 candidate pair and is kept for the thesis appendix — see
  [`dtu_methods.md`](dtu_methods.md).
- The child `nf-core/scrnaseq` run honours a user-supplied `custom.config`
  (`child_config` → `custom.config`, `src/pipeline/modules/align.nf`), but the
  in-repo default only overrides the simpleaf container — it does not scale the
  child's cpus/memory automatically. This is the open item that used to be
  `docs/todo.txt`.
- `confront_clusters.R`, the eight-GEO-matrix Seurat build, and the `deli.*`
  DTU formulations are **not** ported (see [`dtu_methods.md`](dtu_methods.md) and
  [`../src/analysis/README.md`](../src/analysis/README.md)).
