# 4. Transcript-Level Quantification

This document details the methods and configuration parameters used to extract transcript-level count matrices instead of standard gene-level count matrices from scRNA-seq datasets.

---

## 1. The simpleaf "Cheat"

Standard scRNA-seq mapping pipelines group reads by gene to build a cell-by-gene expression matrix. To evaluate COTAN's performance on isoforms, we require a **cell-by-transcript-isoform** expression matrix. We achieve this using a computational adjustment inside the `simpleaf` index:

### Step 1: Modifying the `t2g` Map to an Identity Matrix
* **Standard Mapping**: In a standard alignment run, `simpleaf` uses a transcript-to-gene (`t2g`) mapping file (e.g. `tx2gene.tsv`) to associate transcript IDs with gene IDs:
  ```tsv
  ENSMUST00000188681.2   ENSMUSG00000025902.13
  ENSMUST00000208659.1   ENSMUSG00000025902.13
  ```
  This collapses all multi-mapping reads between these transcripts into a single gene count.
* **Identity Cheat**: We modify this `t2g` matrix into an identity map where each transcript ID maps to itself as the gene ID:
  ```tsv
  ENSMUST00000188681.2   ENSMUST00000188681.2
  ENSMUST00000208659.1   ENSMUST00000208659.1
  ```
  This forces `simpleaf` (and `Alevin` under the hood) to treat every transcript isoform as an independent gene entity.

### Step 2: Bypassing Gene Symbol Annotation in nf-core
* **The Issue**: The `nf-core/scrnaseq` pipeline has downstream post-processing steps (including AnnData conversion) that expect a map of gene IDs to gene symbols (e.g. converting `ENSMUSG...` to `Gapdh`). When given a transcript-level index, these steps fail because they cannot find matching symbols for transcript IDs.
* **The Fix**: We delete the gene ID-to-name annotation matrix from the index folder. This forces `nf-core/scrnaseq` to skip the symbol annotation step, preserving the raw Ensembl Transcript IDs (e.g. `ENSMUST...`) as the final row names of the output matrix.

---

## 2. Alignment Execution and Parameters

The alignment pipeline is executed within the [main.nf](../src/pipeline/main.nf) workflow via the `ALIGN_SIMPLEAF` process.

### Configuration (`nextflow.config`)
Parameters are declared in the `scrnaseq_params` map in [nextflow.config](../src/pipeline/nextflow.config) (per-run overrides live in `runs/<dataset>/nextflow.config`):
```groovy
params {
    scrnaseq_params = [
        skip_multiqc           : true,
        skip_fastqc            : true,
        protocol               : "10xv3",
        simpleaf_umi_resolution: "parsimony-em",
        custom_geometry        : ""
    ]
}
```

### Execution Flow
1. **Samplesheet assembly** (in `src/pipeline/subworkflows/preprocessing.nf`): the fastq files channel is gathered with Nextflow's `.collectFile(name: 'input.csv', …)` operator into the single CSV the child pipeline consumes. `ALIGN_SIMPLEAF` then writes `nf-params.json` via `writeParamsJson()`, pointing `simpleaf_index` at the identity index directory.
2. **`ALIGN_SIMPLEAF` (Native `exec:` Cascade Block)**: Runs natively on the head node using a Nextflow `exec:` block to bypass staging issues and resolve the nested temporary work directory bug (`Invalid include source`). It operates as follows:
   * **Directories**: Uses the preprocessing run directory (`params.preprocessing_dir`, `${launchDir}/results/preprocessing` by default) and stages execution there.
   * **Container Configuration**: Writes a `custom.config` inside that directory. When `params.child_config` points at an existing file it is copied verbatim; otherwise the default only overrides the simpleaf index/quant tools with version `0.24.1--hd612981_0`:
     ```groovy
     process {
         withName: 'SIMPLEAF_INDEX|SIMPLEAF_QUANT' {
             container = 'https://depot.galaxyproject.org/singularity/simpleaf:0.24.1--hd612981_0'
         }
     }
     ```
     The per-run `runs/<dataset>/custom.config` is what carries the child's cpus/memory (via `child_config = "custom.config"`).
   * **Execution**: Natively unsets `NXF_OPTS` and `NXF_CONFIG_FILES`, exports `NXF_SYNTAX_PARSER=v1` (forces parser compatibility with nf-core/scrnaseq 4.1.0 under Nextflow 26+), and starts the child pipeline:
     ```bash
     nextflow run nf-core/scrnaseq \
         -r 4.1.0 \
         -profile singularity \
         -resume \
         -c custom.config \
         -params-file nf-params.json
     ```
3. **Space Reclamation**: Deletes the child workflow's temporary `work/` folder inside the preprocessing directory upon successful completion to save disk space.
