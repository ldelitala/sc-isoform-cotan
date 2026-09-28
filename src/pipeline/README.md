# `src/pipeline/` — Nextflow half

Turns SRA accessions into a cell-by-isoform Seurat matrix. Three steps, each a
self-contained Nextflow stage. Run it from inside a per-dataset run directory
(`work/<dataset>/pipeline/`) so `launchDir` resolves the output paths.

Advised hardware: ~88 cores / ~2 TB RAM. The `align` step runs the child
`nf-core/scrnaseq` natively on the head node and stages downloads in `/dev/shm`,
so a high-RAM head node is the main requirement.

## Steps — and when to use each

| Step | What it does | When to run |
| :--- | :--- | :--- |
| `download` | Fetch FASTQs/BAMs for the accessions in the samplesheet | data missing |
| `index` | Download Ensembl FASTA/GTF and build a simpleaf (Piscem) index | index missing |
| `align` | `download` + `index` as needed, then run `nf-core/scrnaseq` and stage the raw matrix | **default; the full chain** |

`main.nf` accepts only these three (`valid_steps`); there is no `all`/`filter` step.
`align` runs `PREPROCESSING` = `ALIGN_SIMPLEAF`, which stages
`raw_matrix.seurat.rds`; the R analysis does its own QC. Run:

```bash
cd work/<dataset>/pipeline
./run_pipeline.sh        # -> nextflow run .../src/pipeline/main.nf \
                         #      -c nextflow.config -profile singularity -resume
```

`--step` selects `download`, `index` or `align`; `align` is the default.

## The samplesheet

A CSV with columns `sample,sra`, one row per run:

```csv
sample,sra
banchmark_mix,SRR26127904
banchmark_mix,SRR26127905
```

`CHECK_LAYOUT` queries the ENA API per `sra` and branches: **PAIRED** runs go
through `DOWNLOAD_FASTQ` (`prefetch` + `fasterq-dump` + `pigz`); **BAM** runs
(10x Cell Ranger uploads, barcodes/UMIs in `CB`/`UB` tags) go through
`DOWNLOAD_BAM` (`prefetch --type TenX` + `bamtofastq`), because plain
`fasterq-dump` discards the barcode/UMI tags.

## The transcript "cheat"

Standard scRNA-seq pipelines group reads by gene. To get a **cell-by-isoform**
matrix, `2.3_index_apply_cheat.sh` (`APPLY_TRANSCRIPT_CHEAT`) modifies the
`simpleaf` index after it is built:

1. Rewrites `t2g_3col.tsv` so each transcript maps to **itself** — a transcript
   ID becomes its own gene ID, so `simpleaf`/`Alevin` treat every isoform as an
   independent entity and isoforms stop collapsing into genes.
2. Deletes `gene_id_to_name.tsv` — `nf-core/scrnaseq`'s gene-symbol annotation
   step would fail on transcript IDs and be skipped, keeping Ensembl transcript
   IDs (`ENSMUST…`/`ENST…`) as the matrix rows.
3. Writes `mt_transcripts.txt` (mitochondrial transcript IDs) into the index.

## Processes

| Process | Stage script (`bin/`) | Notes |
| :--- | :--- | :--- |
| `CHECK_LAYOUT` | `1.1_ingest_check_layout.sh` | ENA API → `SINGLE`/`PAIRED`/BAM |
| `DOWNLOAD_BAM` | `1.2_ingest_download_bam.sh` | `prefetch --type TenX` + `bamtofastq` |
| `DOWNLOAD_FASTQ` | `1.3_ingest_download_fastq.sh` | `prefetch` + `fasterq-dump` + `pigz` |
| `DOWNLOAD_REFERENCE` | `2.1_index_download_reference.sh` | Ensembl download, `primary_assembly`→`toplevel` fallback |
| `BUILD_INDEX` | `2.2_index_build_index.sh` | `simpleaf index` |
| `APPLY_TRANSCRIPT_CHEAT` | `2.3_index_apply_cheat.sh` | identity `t2g` + `mt_transcripts.txt` |

`DOWNLOAD_BAM`/`DOWNLOAD_FASTQ` carry `maxForks: 4` (concurrency limit on shared
resources) and stage intermediate files entirely in RAM (`scratch '/dev/shm'`).

## Containers

- Index build: `simpleaf:0.24.0--hd612981_1` (`modules/index.nf`)
- Child alignment/quant: `simpleaf:0.24.1--hd612981_0` (`modules/align.nf`)
- `nf-core/scrnaseq` pinned to **4.1.0**, launched as a child Nextflow run inside
  an `exec:` block with `NXF_SYNTAX_PARSER=v1` (forces parser compatibility with
  nf-core/scrnaseq 4.1.0 under Nextflow 26+).
- Ensembl reference release **102**.

## The `align` child-run mechanics

`ALIGN_SIMPLEAF` runs **natively on the head node** in an `exec:` block, bypassing
containerized worker-node staging (this also works around the nested-work-directory
bug). It:

1. Sets up a preprocessing run directory (`params.preprocessing_dir`, by default
   `${launchDir}/results/preprocessing`).
2. Writes a `custom.config` there — if `params.child_config` points at an existing
   file it is copied verbatim (the per-run `work/<dataset>/pipeline/custom.config`
   is what carries the child's cpus/memory); otherwise the default only overrides
   the simpleaf index/quant containers to `0.24.1--hd612981_0`.
3. Assembles the samplesheet with Nextflow's `.collectFile()` operator into
   `input.csv`, and writes `nf-params.json` via `writeParamsJson()` (points
   `simpleaf_index` at the identity index, protocol `10xv3`,
   `simpleaf_umi_resolution: parsimony-em`, `skip_multiqc`/`skip_fastqc: true`).
4. Starts the child pipeline, unsets `NXF_OPTS`/`NXF_CONFIG_FILES`, exports
   `NXF_SYNTAX_PARSER=v1`:
   ```bash
   nextflow run nf-core/scrnaseq -r 4.1.0 -profile singularity -resume \
       -c custom.config -params-file nf-params.json
   ```
5. Stages `raw_matrix.seurat.rds` to the target `unfiltered_dir` (the handoff to
   `src/analysis/`), and deletes the child workflow's temporary `work/` folder on
   success to save disk space.

## Gotchas

- **RAM-disk policy.** Downloads stage in `/dev/shm` (`scratch '/dev/shm'`);
  never write raw SRA/BAM to persistent disk (~18 GB BAM / ~8 GB zipped FASTQ per
  sample, ~26 GB if both are staged).
- **Resource overrides.** The per-run `nextflow.config` (`-c`) plus `custom.config`
  for the child pipeline are the only override mechanism; there is no `central.config`.
- **COTAN p-value ceiling.** `COTAN::calculatePValue()` segfaults at ≥46,341
  features (32-bit overflow when subsetting `dspMatrix`); keep features < ~41,000.
  This is a downstream (R) constraint, but it shapes what this half may output;
  see `src/analysis/README.md` and `docs/dtu_methods.md`.
