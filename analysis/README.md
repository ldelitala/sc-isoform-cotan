# `analysis/` — downstream DTU analysis

The R half of the project. It takes a filtered single-cell count matrix and produces
the differential transcript usage (DTU) candidate tables that the thesis reports.

It sits between two other pieces of the repository:

```
src/pipeline/            Nextflow: SRA -> simpleaf index -> align -> QC filter
   |                     (last artefact: runs/<dataset>/results/sample_filtered.rds)
   v
analysis/                this layer: Seurat clean-up -> COTAN -> COEX -> GDI -> clustering
   |                     -> DTU candidates -> gene/transcript comparison
   v
cotanisoform/            the R package with the actual algorithms, used by every step here
```

`analysis/` is **not** invoked by Nextflow. The hand-off is a Seurat object placed under
`data/project_files/<dataset>/`; `src/pipeline/bin/5.1_downstream_cotan.R` is an empty
placeholder and is handled separately (see the cleanup plan S7).

## Layout

```
analysis/
├── run_all.R              runs the steps listed in a config, in order
├── lib/common.R           CLI, config loading, path resolution, logging (sourced by every step)
├── config/
│   ├── arrigoni.yaml                     GSE243665, transcript level
│   ├── ding_cortex_2.transcript.yaml     GSE132044 cortex, transcript level
│   └── ding_cortex_2.gene.yaml           GSE132044 cortex, gene level
└── R/
    ├── 00_build_t2gene_name.R   transcript -> gene name map from the aligner index
    ├── 01_prepare_seurat.R      barcode clean-up, spliced filter, count rounding
    ├── 02_init_cotan.R          COTAN object + cell/gene metadata
    ├── 03_calc.R                lambda/nu estimation, COEX, p-values, GDI   (expensive)
    ├── 04_gdi.R                 GDI plot over a marker panel
    ├── 05_cluster.R             cell clustering (guided or unguided)
    ├── 06_transfer_cluster.R    copy gene-level cluster labels onto the transcript object
    ├── 07_dtu.R                 DTU candidate extraction                     (the result)
    └── 08_compare_dtu.R         shared / exclusive tables between two candidate tables
```

## Running

Every step takes the same options:

```bash
Rscript analysis/R/07_dtu.R --config analysis/config/arrigoni.yaml              # do the work
Rscript analysis/R/07_dtu.R --config analysis/config/arrigoni.yaml --dry-run    # print the plan, change nothing
Rscript analysis/R/07_dtu.R --config analysis/config/arrigoni.yaml --out-dir /tmp/scratch
```

| Option | Meaning |
| :--- | :--- |
| `--config FILE` | the dataset config; required |
| `--root DIR` | override the config's `root:` (also the `COTANISO_ROOT` env var) |
| `--out-dir DIR` | write this step's outputs **and log** into `DIR`; the config paths stay untouched |
| `--dry-run` | resolve and print every input/output, then exit 0 without computing |

`--out-dir` also *shadows inputs*: when `DIR` already contains a file with the same name
as a configured input, that copy is used. A chained scratch run therefore feeds itself,
and a single-step re-run reads the real objects but never overwrites them.

Whole pipelines:

```bash
Rscript analysis/run_all.R --config analysis/config/arrigoni.yaml
Rscript analysis/run_all.R --config analysis/config/ding_cortex_2.transcript.yaml --from 07 --to 08
Rscript analysis/run_all.R --config analysis/config/ding_cortex_2.gene.yaml --dry-run
```

`run_all.R` executes one R process per step, in the order given by the config's `run:`
list, and stops at the first failure. `--from`/`--to` take step numbers, which is how the
hours-long `03_calc` is skipped when the calculated object already exists.

Always run from inside the repository (`analysis/...` paths above are relative to it) and
with an R environment that has `cotanisoform` installed — the conda environment `deli` on
athena is the one used for the published results:

```bash
Rscript analysis/run_all.R --config analysis/config/arrigoni.yaml
```

## Config

One YAML per dataset and level. Paths are relative to `root:`, which is the only
machine-specific value in the file, so the same config runs on another machine with
`--root /other/place`. Everything the released drivers hardcoded — genome, GEO metadata,
marker panels, core counts, clusterization names, DTU thresholds — lives here.

```yaml
root: /data/lorenzo_delitala        # machine root
dataset: arrigoni
level: transcript                   # gene | transcript
meta: {geo_id: GSE243665, seq_method: 10xv1, condition: Transcript_Arrigoni}
logging_level: 3
run: ["00", "01", "02", "03", "04", "05", "07"]     # steps this dataset uses

paths:            # every input path and output directory, relative to root
  workdir, logs, objects, plots, t2g, gene_id_to_name, t2gene_name,
  input_seurat (or input_matrix + input_matrix_genes + input_matrix_cells),
  valid_cells_tsv (or cell_type_files: {cell line: barcode file})

objects:          # file names inside paths.objects, i.e. the chain between steps
  ready_seurat, initialized, calculated, clustered, ...

steps:            # per-step parameters
  prepare_seurat, init_cotan, calc, gdi, clustering, transfer_cluster, dtu, compare_dtu
```

Two shapes exist, and a step refuses a config that lacks its inputs (it says which key is
missing):

* **transcript level** — starts from a Seurat object; `init_cotan` is fed by
  `objects.ready_seurat`, optional `cell_type_files` become a `Known_Cell_Types`
  clusterization, and `add_gene_info_from_t2g` attaches `gene_id`/`gene_name`.
* **gene level** — has `steps.init_cotan.matrix` instead of `paths.input_seurat`, and step
  02 builds the COTAN object directly from the GEO count matrix (`input_matrix`).

The DTU step lists one entry per clusterization, because one object can hold several:

```yaml
steps:
  dtu:
    input_object: with_gene_labels
    recompute_dea: auto        # auto | always | never
    p_value_threshold: 0.05
    min_dea_contrast: 0.05
    gene_name_col: gene_name
    outputs:
      - {clusterization: merged,             file_name: dtu_candidates.transcript_cluster.csv}
      - {clusterization: local_gene_cluster, file_name: dtu_candidates.gene_cluster.csv}
```

`recompute_dea: auto` reuses the differential expression stored in the object when it is
present *and finite*, and runs `dea_on_clusters()` otherwise. This matters because
`06_transfer_cluster.R` injects a clusterization with an **empty** DEA frame — a stored but
useless matrix — so "the clusterization exists" is not a sufficient test.

The `COEX <= 0` rule of the DTU step is hard-coded inside
`cotanisoform::extract_dtu_candidates()`; there is no config key for it.

## Outputs

| Step | Writes | Published copy |
| :--- | :--- | :--- |
| 00 | `paths.t2gene_name` | `results/<dataset>/t2gene_name.tsv` |
| 01 | `objects.ready_seurat` | — (intermediate) |
| 02 | `objects.initialized`, combined QC TSV | `results/arrigoni/GSE243665_combined_QC_barcodes.tsv` |
| 03 | `objects.calculated` | — (multi-GB intermediate) |
| 04 | `plots/<gdi file_name>` | `results/<dataset>/plots/` |
| 05 | `objects.clustered` | — (intermediate) |
| 06 | `clustered.*.with_gene_labels.rds` | — (intermediate) |
| 07 | one CSV per `dtu.outputs` entry | `results/<dataset>/dtu_candidates*.csv` |
| 08 | `dtu_shared.csv`, `dtu_exclusive_file{1,2}.csv` | `results/ding_cortex_2/` |

`pipeline/scripts/collect_results.sh` copies these into `results/`.

Logs go to `paths.logs` (or `--out-dir`) as `<step>.<level>.log`, with `_N` appended when
a file with that name already exists. The released runs logged step 07 under the
`cotan_calc` name (copied from the calc step), so the DTU logs in `results/**/logs/` are
called `cotan_calc*.log`.

## Data prerequisites

Kept on athena, not in git (too large):

* `data/project_files/<dataset>/raw_matrix.seurat.rds` — the pipeline's Seurat output with
  spliced/unspliced/ambiguous layers (step 01 input).
* `data/geo_metadata/**` — GEO barcode files used for QC flags and cell types.
* `data/genomes/{GRCh38,GRCm39}/gene_index/index/` — `t2g_3col.tsv` and
  `gene_id_to_name.tsv` from the aligner run (step 00 input).
* for the gene-level cortex run: `GSE132044_cortex_mm10_{count_matrix.mtx,gene.tsv,cell.tsv}.gz`.

## What is verified, and what is not

Verified against the published results (2026-09-22, on the real objects):

* **`00_build_t2gene_name.R`** reproduces the published `t2gene_name.tsv`
  byte-identically for arrigoni and for ding cortex_2.
* **`07_dtu.R`** reproduces all three published DTU tables: arrigoni and
  ding `gene_cluster` byte-identically, ding `transcript_cluster` identically in value
  (that release had been re-serialised unquoted). The same check is automated in
  `pipeline/scripts/verify_dtu_parity.R`, which also asserts the run-log fingerprints.

**Transcribed but not re-executed: 01, 02, 03, 04, 05, 06, 08.** Re-running `03_calc`
costs hours of COEX work and re-running `05_cluster` is an optimisation whose outcome is
not defined in advance; their configs are validated with `--dry-run` and their arguments
are the released ones. Their **inputs** are the real objects, except `01`, whose input is
the raw Seurat object.

Deliberate deviations from the released drivers, all documented in the configs:

* One core count and chunk size per dataset instead of the mixed values
  (`calc.gdi_cores` exists for runs that used more cores for the GDI step).
* `objects.calculated` for arrigoni names `calculated.cotan.rds`, the object the released
  DTU step actually read, not the later re-run `calculated.transcript.cotan.rds`.
* No `coex_threshold` parameter, and `min_dea_contrast` is 0.2 (arrigoni) / 0.05 (ding) —
  the values that produced the published tables. `-0.1 / 0.5` belonged to an abandoned
  scratch variant that never produced a published table.

## Not ported

* `confront_clusters.R` — compared two clusterizations of the same object as an
  intermediate sanity check; it produced none of the published results.
* the `00_create_seurat.R` ingestion script — builds a Seurat object from eight GEO
  matrix triples. That is dataset ingestion; it is described above as a prerequisite
  instead of becoming a step.
* the alternative DTU formulations from the removed `deli.*` packages — never run on the
  published datasets. The two implementations are kept under
  [`analysis/deprecated/`](deprecated/README.md), with their semantics in
  `docs/dtu_methods.md`.

Two archived driver scripts were faulty and explain why the snapshots were illustrative,
not an exact record of what ran: the `transcript/05_cluster.R` copy did not parse (a
missing comma after `cl_name = "local_transcript_cluster"`), and the arrigoni `06_dtu.R`
named its output `dtu_candidates.known_cell_types.csv` although the published artefact is
`dtu_candidates.csv`. That same script also assigned the result of
`extract_dtu_candidates()` over the COTAN object, which cannot work (the function returns
the candidate table), so its second extraction never produced the second arrigoni table.
This directory is the record; the `results/**/Rscripts/` snapshots were removed in S7.
