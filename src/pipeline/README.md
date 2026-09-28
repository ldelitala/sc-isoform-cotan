# `src/pipeline/` — Nextflow half

This half turns SRA accessions into a raw cell-by-isoform Seurat matrix. It is
a small Nextflow pipeline with three steps — `download`, `index` and `align` —
run from inside a per-dataset run directory, with all output paths resolved
relative to the launch directory.

Advised hardware: roughly 88 cores and 2 TB of RAM. The heaviest step runs the
alignment natively on the head node and stages downloads in RAM (`/dev/shm`), so
a high-RAM head node is the main requirement.

## The interface

The pipeline has a single entry point and a `--step` flag that selects which
stage to run.

| `--step` | What it does | When to use |
| :--- | :--- | :--- |
| `download` | Fetch the FASTQs/BAMs listed in the samplesheet | data missing |
| `index` | Download the Ensembl reference (FASTA/GTF) and build the `simpleaf` (Piscem) index | index missing |
| `align` | Full chain: `download` + `index` as needed, then `nf-core/scrnaseq`; stages `raw_matrix.seurat.rds` | **default; run this to go end-to-end** |

`main.nf` accepts only these three steps (`valid_steps`); there is no `all` or
`filter` step. QC filtering is not part of this half — it happens later, in the
R analysis.

## Running the pipeline

The entry point is `nextflow run .../src/pipeline/main.nf`. It takes a per-run
config file, the Singularity profile, and a `--step` flag selecting the stage:

```bash
nextflow run .../src/pipeline/main.nf \
    -c nextflow.config -profile singularity --step align
```

`-c nextflow.config` supplies the configuration file with all the settings the
pipeline needs, `-profile singularity` runs every process in a Singularity
container, and `--step` selects `download`, `index` or `align`. The `align` step
(the default) is the full chain: it downloads any missing data, builds the index
if needed, runs `nf-core/scrnaseq`, and stages the raw cell-by-isoform matrix as
`raw_matrix.seurat.rds`.

### The configuration file

`nextflow.config` is a single file holding every setting the pipeline needs.
It is split into three blocks: `params` (pipeline parameters), `executor`/
`process` (resource limits), and `profiles` (container profiles). A minimal
working config looks like this:

```groovy
params {
    step            = "align"     // which step: download, index, align
    input           = "samplesheet.csv" // mandatory: CSV (sample, sra)

    genome_species  = "homo_sapiens"    // species for the Ensembl download
    genome_assembly = "GRCh38"          // assembly, e.g. GRCh38 / GRCm38
    ensembl_release = 102

    transcript_level = true     // true = isoform-level, false = gene-level
    skip_simpleaf    = false
}

executor {
    name = 'local'
}

process {
    cpus   = 2
    memory = 4.GB

    withName: 'ALIGN_SIMPLEAF|BUILD_INDEX' { cpus = 8; memory = 16.GB }
    withName: 'DOWNLOAD_BAM|DOWNLOAD_FASTQ' {
        maxForks = 4; errorStrategy = 'retry'; maxRetries = 2
    }
}

profiles {
    singularity { singularity.enabled = true; singularity.autoMounts = true }
}
```

The key values to set for a new dataset are the **mandatory** `input` (the
samplesheet path) and the **reference** settings `genome_species` and
`genome_assembly` — everything else has a working default. `transcript_level`
must stay `true` for this thesis's isoform-level goal. The per-dataset run
directory keeps its own customized `nextflow.config`, so the plain
`./run_pipeline.sh` invocation picks it up automatically.

Every parameter, the resource blocks, and the container profiles are documented
in full in [`CONFIG.md`](CONFIG.md).

For convenience there is also a quick wrapper, `run_pipeline.sh`, which lives in
the per-dataset run directory and fills in the boilerplate above — the config,
the profile, and `-resume` (so a rerun continues from where it left off). Run it
from that directory with no flags to get the whole pipeline:

```bash
cd work/<dataset>/pipeline
./run_pipeline.sh
```

To run just one step through the wrapper, pass the same flag through:
`--step download`, `--step index`, or `--step align`.

## The samplesheet

The samplesheet lives next to the wrapper, in the per-dataset run directory at
`work/<dataset>/pipeline/samplesheet.csv`. It is attached to the pipeline as the
mandatory `params.input` — a CSV with two columns, `sample` and `sra`, one row
per run:

```csv
sample,sra
banchmark_mix,SRR26127904
banchmark_mix,SRR26127905
```

The per-run `nextflow.config` points `input` at that file, so the plain
`./run_pipeline.sh` invocation picks it up automatically. To point the pipeline
at a different sheet, pass its path explicitly:

```bash
nextflow run .../src/pipeline/main.nf \
    -c nextflow.config -profile singularity --step align --input samplesheet.csv
```

For each accession the pipeline queries the ENA API to detect the run layout and
branches accordingly:

- **PAIRED runs** go through the FASTQ download path (`prefetch` +
  `fasterq-dump` + `pigz`).
- **BAM runs** (10x Cell Ranger uploads, barcodes/UMIs in `CB`/`UB` tags) go
  through the BAM download path (`prefetch --type TenX` + `bamtofastq`), because
  plain `fasterq-dump` would discard the barcode/UMI tags.

## The transcript "cheat"

Standard scRNA-seq pipelines group reads by gene. This pipeline instead wants a
**cell-by-isoform** matrix, so after the index is built it modifies it so that
every transcript is treated as an independent entity:

1. The `t2g_3col.tsv` mapping is rewritten so each transcript maps to **itself** —
   a transcript ID becomes its own gene ID, so `simpleaf`/`Alevin` treat every
   isoform as an independent entity and isoforms stop collapsing into genes.
2. The `gene_id_to_name.tsv` file is deleted, so the gene-symbol annotation step
   fails on transcript IDs and is skipped — keeping Ensembl transcript IDs
   (`ENSMUST…`/`ENST…`) as the matrix rows.
3. A `mt_transcripts.txt` list of mitochondrial transcript IDs is written into
   the index, so the downstream QC can filter them.

## Processes

| Process | Stage script (`bin/`) | Notes |
| :--- | :--- | :--- |
| `CHECK_LAYOUT` | `1.1_ingest_check_layout.sh` | ENA API → `SINGLE`/`PAIRED`/BAM |
| `DOWNLOAD_BAM` | `1.2_ingest_download_bam.sh` | `prefetch --type TenX` + `bamtofastq` |
| `DOWNLOAD_FASTQ` | `1.3_ingest_download_fastq.sh` | `prefetch` + `fasterq-dump` + `pigz` |
| `DOWNLOAD_REFERENCE` | `2.1_index_download_reference.sh` | Ensembl download, `primary_assembly`→`toplevel` fallback |
| `BUILD_INDEX` | `2.2_index_build_index.sh` | `simpleaf index` |
| `APPLY_TRANSCRIPT_CHEAT` | `2.3_index_apply_cheat.sh` | identity `t2g` + `mt_transcripts.txt` |

`DOWNLOAD_BAM`/`DOWNLOAD_FASTQ` carry `maxForks: 4` (a concurrency limit on
shared resources) and stage intermediate files entirely in RAM
(`scratch '/dev/shm'`).

## Containers

- Index build: `simpleaf:0.24.0--hd612981_1` (`modules/index.nf`)
- Child alignment/quant: `simpleaf:0.24.1--hd612981_0` (`modules/align.nf`)
- `nf-core/scrnaseq` pinned to **4.1.0**, launched as a child Nextflow run inside
  an `exec:` block with `NXF_SYNTAX_PARSER=v1` (forces parser compatibility with
  nf-core/scrnaseq 4.1.0 under Nextflow 26+).
- Ensembl reference release **102**.

## The `align` child-run mechanics

`ALIGN_SIMPLEAF` runs **natively on the head node** in an `exec:` block,
bypassing containerized worker-node staging (this also works around the
nested-work-directory bug). It:

1. Sets up a preprocessing run directory (`params.preprocessing_dir`, by default
   `${launchDir}/results/preprocessing`).
2. Writes a `custom.config` there — if `params.child_config` points at an
   existing file it is copied verbatim (the per-run
   `work/<dataset>/pipeline/custom.config` carries the child's cpus/memory);
   otherwise the default only overrides the simpleaf index/quant containers to
   `0.24.1--hd612981_0`.
3. Assembles the samplesheet with Nextflow's `.collectFile()` operator into
   `input.csv`, and writes `nf-params.json` via `writeParamsJson()` — pointing
   `simpleaf_index` at the identity index, protocol `10xv3`,
   `simpleaf_umi_resolution: parsimony-em`, `skip_multiqc`/`skip_fastqc: true`.
4. Starts the child pipeline, unsets `NXF_OPTS`/`NXF_CONFIG_FILES`, exports
   `NXF_SYNTAX_PARSER=v1`:
   ```bash
   nextflow run nf-core/scrnaseq -r 4.1.0 -profile singularity -resume \
       -c custom.config -params-file nf-params.json
   ```
5. Stages `raw_matrix.seurat.rds` to the target `unfiltered_dir` (the handoff to
   `src/analysis/`), and deletes the child workflow's temporary `work/` folder on
   success to save disk space.

## Operational notes

- **RAM-disk policy.** Downloads stage in `/dev/shm` (`scratch '/dev/shm'`);
  raw SRA/BAM data is never written to persistent disk (~18 GB BAM / ~8 GB
  zipped FASTQ per sample, ~26 GB if both are staged).
- **Resource overrides.** The per-run `nextflow.config` (`-c`) plus
  `custom.config` for the child pipeline are the only override mechanism; there
  is no `central.config`.
- **COTAN p-value ceiling.** `COTAN::calculatePValue()` segfaults at ≥46,341
  features (a 32-bit overflow when subsetting `dspMatrix`); keep features below
  ~41,000. This is a downstream (R) constraint, but it shapes what this half may
  output; see `src/analysis/README.md` and `docs/dtu_methods.md`.
