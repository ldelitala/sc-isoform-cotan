# Docs index

These are design notes written at different times. **Some are historical** and no
longer match the code. For the current picture, read the repository
[`README.md`](../README.md) and the code itself; use this index to know what each
file is worth.

| File | Covers | Status |
| :--- | :--- | :--- |
| `pipeline_architecture_workflows.md` | End-to-end Nextflow spec + Mermaid DAG, process-by-process | Mostly accurate; still says step `all`/`filter` and container `0.22.0` |
| `pipeline_workflow.md` | Short flow diagram of the nextflow stages | Mostly accurate |
| `1_configuration_parameters.md` | Parameter reference | **Partly stale** (old names: `srr_ids`, `index_dir`, `genome`, step `all`/`filter`) |
| `2_cluster_resource_management.md` | Thread/memory math, RAM-disk policy | The resource math is useful; the `central.config` mechanism is not how runs are actually configured |
| `3_data_ingestion.md` | SRA/BAM ingestion formats, storage policy, target datasets | Accurate for the ingestion design |
| `4_transcript_quantification.md` | The simpleaf transcript "cheat" + child run | Accurate in intent; container tag `0.22.0` is outdated |
| `5_qc_filtering.md` | QC logic + mitochondrial-at-transcript-level problem | Accurate |
| `6_downstream_analysis.md` | COTAN downstream plan + verification strategy | Plan/aspirational (SCALPEL path not implemented) |
| `7_script_architecture.md` | Per-process interfaces | Mostly accurate |
| `LINEE GUIDA.md` | Aspirational "isoform-aware COTAN nextflow" design (5 COTAN stages) | **Not implemented** in the Nextflow half; the COTAN stages exist as R package functions instead |
| `todo.txt` | Open task: child nf-core run should honour custom cpus/memory | Open |

## Ground truth

When a doc disagrees with code, the code wins. The most reliable sources:

- `src/pipeline/main.nf` + `src/pipeline/nextflow.config` — actual steps/params
- `src/pipeline/modules/*.nf` — process definitions and script arguments
- `src/pipeline/bin/*` — what each stage actually does
- `src/libs/*/NAMESPACE` — exported R functions
