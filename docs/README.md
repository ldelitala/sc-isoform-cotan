# Docs index

Design notes and reference material for the repository. **Code wins over these
documents** — when they disagree, trust `src/pipeline/`, `src/analysis/` and
`src/cotanisoform/`. Start with the repository [`README.md`](../README.md) and
[`src/analysis/README.md`](../src/analysis/README.md).

## Current

| File | Covers |
| :--- | :--- |
| [`3_data_ingestion.md`](3_data_ingestion.md) | SRA ingestion layouts (FASTQ / BAM), RAM-disk storage policy, datasets ingested |
| [`4_transcript_quantification.md`](4_transcript_quantification.md) | The simpleaf transcript "cheat" and the child `nf-core/scrnaseq` run |
| [`5_qc_filtering.md`](5_qc_filtering.md) | QC thresholds and mitochondrial detection at transcript level |
| [`7_script_architecture.md`](7_script_architecture.md) | Per-process interfaces and resource directives |
| [`pipeline_workflow.md`](pipeline_workflow.md) | Short flow diagram of the Nextflow stages |
| [`athena_layout.md`](athena_layout.md) | Folder layout and sizes on athena, access/tunnel notes, what is safe to delete |
| [`data_availability.md`](data_availability.md) | GEO/SRA accessions, assemblies, how to re-download, reference policy |
| [`dtu_methods.md`](dtu_methods.md) | The canonical DTU definition, the p-value model, and the two unused alternatives |
| [`reproducibility.md`](reproducibility.md) | End-to-end rerun, where outputs land, how to skip expensive steps |
| [`software_versions.md`](software_versions.md) | R / COTAN / Nextflow / container version pins |
| [`cotan_pvalue_segfault.md`](cotan_pvalue_segfault.md) | COTAN `calculatePValue()` segfault at ≥46,341 features and the workaround |
| [`TODO.md`](TODO.md) | Open backlog items (currently: per-cluster isoform-proportion plots for the headline candidates) |

## Notes

| File | Covers |
| :--- | :--- |
| [`notes/thesis-topic.md`](notes/thesis-topic.md) | Personal working notes framing the thesis (not documentation) |

## Legacy

[`legacy/`](legacy/README.md) holds design documents written earlier in the
project. They describe a flat repository layout, steps `all`/`filter`, old
parameter names (`srr_ids`, `index_dir`, `genome`) and an outdated simpleaf container tag, none of
which exist any more. Kept for the design record only — see
[`legacy/README.md`](legacy/README.md).

## Ground truth

- `src/pipeline/main.nf` + `src/pipeline/nextflow.config` — actual steps/params
- `src/pipeline/modules/*.nf` — process definitions and script arguments
- `src/pipeline/bin/*` — what each stage actually does
- `src/analysis/README.md` — the downstream driver
- `src/cotanisoform/NAMESPACE` — exported R functions
