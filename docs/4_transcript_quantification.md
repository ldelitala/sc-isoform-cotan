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

The alignment pipeline is executed within the [main.nf](file:///home/deli/athena_mount/main.nf) workflow via the `ALIGN_SIMPLEAF` process.

### Configuration (`nextflow.config`)
Parameters are declared in the `scrnaseq_params` map in [nextflow.config](file:///home/deli/athena_mount/nextflow.config):
```groovy
params {
    scrnaseq_params = [
        protocol: "10XV3",
        skip_cellbender: true,
        simpleaf_umi_resolution: "parsimony-em"
    ]
}
```

### Execution Flow
1. **`GENERATE_SAMPLESHEET`**: Scans the fastq files channel, generates the Nextflow-compatible `input.csv` samplesheet, and writes a dynamic `nf-params.json` targeting the identity `simpleaf` index directory:
   `references/indices/<genome>_simpleaf`
2. **`ALIGN_SIMPLEAF`**: Executes `nextflow run nf-core/scrnaseq` inside the workspace task directory using the generated configurations:
   ```bash
   nextflow run nf-core/scrnaseq \
       -r 4.1.0 \
       -profile singularity \
       -params-file nf-params.json \
       --max_cpus 72 \
       --max_memory "2.0 TB"
   ```
3. **Space Reclamation**: The process automatically deletes the nested Nextflow `work/` folder upon successful completion to conserve disk storage.
