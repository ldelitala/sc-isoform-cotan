# `src/pipeline/` — Nextflow half

This half turns SRA accessions into a raw cell-by-isoform Seurat matrix. It is a
small Nextflow pipeline with three steps: `download`, `index` and `align`. You
run it from inside a per-dataset run directory, and it resolves all output paths
relative to where you launch it.

Advised hardware: roughly 88 cores and 2 TB of RAM. The heaviest step runs the
alignment natively on the head node and stages downloads in RAM (`/dev/shm`), so
a high-RAM head node is the main requirement.

## The interface

You drive the pipeline with a single entry point and a `--step` flag.

- **`--step download`** — fetch the FASTQs/BAMs listed in your samplesheet, if
  they are not already present.
- **`--step index`** — download the Ensembl reference (FASTA/GTF) and build the
  `simpleaf` (Piscem) index, if it is not already present.
- **`--step align`** — the default. The full chain: it downloads whatever data
  is missing, builds the index if needed, runs `nf-core/scrnaseq`, and stages
  the raw cell-by-isoform matrix as `raw_matrix.seurat.rds`.

There is no `filter` step and no `all` shortcut — QC filtering is not part of
this half. It happens later, in the R analysis. `align` is the default and the
only step you normally need: a single command with no flags runs the whole
pipeline from accessions to the matrix.

## The samplesheet

The samplesheet is a CSV with two columns, `sample` and `sra`, one row per
run. For each accession, the pipeline queries the ENA API to detect the run
layout and picks the right download path:

- **PAIRED runs** are fetched as FASTQs.
- **BAM runs** (10x Cell Ranger uploads) are fetched as BAMs and converted to
  FASTQs, because plain FASTQ extraction would discard the barcode/UMI tags.

## The transcript "cheat"

Standard scRNA-seq pipelines group reads by gene. This pipeline wants a
**cell-by-isoform** matrix, so it modifies the built index so that every
transcript is treated as its own independent entity:

1. Each transcript ID is made to map to itself, so isoforms stop collapsing into
   their parent genes.
2. The gene-symbol annotation is disabled, keeping Ensembl transcript IDs
   (`ENSMUST…` / `ENST…`) as the matrix rows.
3. Mitochondrial transcript IDs are recorded into the index so the downstream QC
   can filter them.

## Alignment mechanics

The `align` step runs the `nf-core/scrnaseq` pipeline as a child run directly on
the head node. It writes the child's config and parameters into the run
directory, feeds it the assembled samplesheet, and on success stages the raw
matrix to the analysis half and clears the child's temporary working files to
save disk space. The child pipeline is pinned to `nf-core/scrnaseq` 4.1.0 and
the Ensembl reference release is 102.

## Operational notes

- **RAM-disk policy.** Downloads are staged in RAM and never written to
  persistent disk — raw SRA/BAM data is large (~18 GB BAM or ~8 GB zipped FASTQ
  per sample), so keeping it off disk saves a lot of space.
- **Resource overrides.** The per-run `nextflow.config` and the child pipeline's
  `custom.config` are the only way to override CPU/memory. There is no central
  config file.
- **COTAN p-value ceiling.** Downstream, `COTAN::calculatePValue()` segfaults at
  46,341 or more features (a 32-bit overflow), so the matrix should stay below
  ~41,000 features. This is an R-side constraint, but it shapes what this half
  may output; see `src/analysis/README.md` and `docs/dtu_methods.md`.
