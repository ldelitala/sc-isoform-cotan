# `nextflow.config` — Full Configuration Reference

This file is the single configuration source for the Nextflow half. It holds
every setting the pipeline needs, split into three blocks: **`params`**
(pipeline parameters), **`executor`/`process`** (resource limits), and
**`profiles`** (container profiles). The reference lives at
`src/nextflow/nextflow.config`; each per-dataset run directory keeps a
customized copy that the `run_pipeline.sh` wrapper picks up.

## The full file

```groovy
params {
    // --- WORKFLOW CONTROL ---
    step            = "align"        // 'download', 'index', 'align' (default: 'align')
    webhook_url     = secrets.WEBHOOK_URL ?: ""

    // --- DOWNLOAD PHASE OPTIONS ---
    dataset_dir     = "${launchDir}/results/dataset"
    input           = null           // Mandatory. Path to CSV samplesheet (sample, sra)

    // --- INDEXING OPTIONS ---
    skip_simpleaf   = false // if true, gene_index_dir must hold a simpleaf index
    reference_dir   = "${launchDir}/results/reference"
    gene_index_dir  = "${launchDir}/results/gene_index"
    transcript_level = true  // true = isoform-level, false = gene-level
    transcript_index_dir = "${launchDir}/results/transcript_index"

    genome_assembly = ""           // e.g. 'GRCh38', 'GRCm38'
    genome_species  = ""           // e.g. 'homo_sapiens'
    ensembl_release = 102

    // --- ALIGNMENT & PREPROCESSING ---
    scrnaseq_params = [
        skip_multiqc           : true,
        skip_fastqc            : true,
        protocol               : "",
        simpleaf_umi_resolution: "",
        custom_geometry        : ""
    ]
    child_config = ""    // path to custom config for the child scRNA-seq process

    // --- STORAGE PATHS ---
    preprocessing_dir = "${launchDir}/results/preprocessing"
    unfiltered_dir    = "${launchDir}/results/"
}

executor {
    name = 'local'
}

process {
    cpus   = 2
    memory = 4.GB

    withName: 'ALIGN_SIMPLEAF|BUILD_INDEX' {
        cpus   = 8
        memory = 16.GB
    }

    withName: 'DOWNLOAD_BAM|DOWNLOAD_FASTQ' {
        maxForks      = 4
        errorStrategy = 'retry'
        maxRetries    = 2
    }
}

profiles {
    singularity {
        singularity.enabled    = true
        singularity.autoMounts = true
    }

    docker {
        docker.enabled         = true
        docker.runOptions      = '-u $(id -u):$(id -g)'
    }
}
```

## Block 1 — `params`: pipeline parameters

### Workflow control

| Parameter | Default | Meaning |
| :--- | :--- | :--- |
| `step` | `align` | Which step to run: `download`, `index`, or `align`. |
| `webhook_url` | `""` | Optional status webhook; unused unless a secret is set. |

### Download phase

| Parameter | Default | Meaning |
| :--- | :--- | :--- |
| `dataset_dir` | `${launchDir}/results/dataset` | Where fetched reads are staged. |
| `input` | `null` | **Mandatory.** Path to the CSV samplesheet (`sample, sra`). |

### Indexing phase

| Parameter | Default | Meaning |
| :--- | :--- | :--- |
| `skip_simpleaf` | `false` | If `true`, skip building the index; `gene_index_dir` must then already contain a simpleaf index. |
| `reference_dir` | `${launchDir}/results/reference` | Where the Ensembl FASTA/GTF is stored. |
| `gene_index_dir` | `${launchDir}/results/gene_index` | Gene-level index output. |
| `transcript_level` | `true` | `true` = isoform-level matrix, `false` = gene-level. **Keep `true` for the isoform goal.** |
| `transcript_index_dir` | `${launchDir}/results/transcript_index` | Transcript-level index output. |

### Reference

| Parameter | Default | Meaning |
| :--- | :--- | :--- |
| `genome_assembly` | `""` | Assembly to use, e.g. `GRCh38`, `GRCm38`. **Set per dataset.** |
| `genome_species` | `""` | Species name, e.g. `homo_sapiens`. **Set per dataset.** |
| `ensembl_release` | `102` | Ensembl release for the reference download. |

### Alignment / preprocessing

| Parameter | Default | Meaning |
| :--- | :--- | :--- |
| `scrnaseq_params.skip_multiqc` | `true` | Skip MultiQC in the child pipeline. |
| `scrnaseq_params.skip_fastqc` | `true` | Skip FastQC in the child pipeline. |
| `scrnaseq_params.protocol` | `""` | Protocol for `nf-core/scrnaseq` (e.g. `10xv3`). |
| `scrnaseq_params.simpleaf_umi_resolution` | `""` | UMI resolution mode for simpleaf (e.g. `parsimony-em`). |
| `scrnaseq_params.custom_geometry` | `""` | Custom geometry override. |
| `child_config` | `""` | Path to a custom config for the child `nf-core/scrnaseq` run. |

### Storage paths

| Parameter | Default | Meaning |
| :--- | :--- | :--- |
| `preprocessing_dir` | `${launchDir}/results/preprocessing` | Child-run working area. |
| `unfiltered_dir` | `${launchDir}/results/` | Where `raw_matrix.seurat.rds` is staged for the R analysis. |

## Block 2 — `executor` / `process`: resource limits

| Setting | Value | Meaning |
| :--- | :--- | :--- |
| `executor.name` | `local` | Runs processes on the local machine (no cluster scheduler). |
| `process.cpus` | `2` | Default CPUs per process. |
| `process.memory` | `4.GB` | Default memory per process. |
| `ALIGN_SIMPLEAF\|BUILD_INDEX` | `8` cpus / `16.GB` | Override for the heavy alignment/index stages. |
| `DOWNLOAD_BAM\|DOWNLOAD_FASTQ` | `maxForks: 4` | Concurrency limit on shared download resources. |
| `DOWNLOAD_BAM\|DOWNLOAD_FASTQ` | `errorStrategy: retry`, `maxRetries: 2` | Download retry policy. |

## Block 3 — `profiles`: container profiles

| Profile | Purpose |
| :--- | :--- |
| `singularity` | Runs every process in a Singularity container; auto-mounts host paths. Used by the default command. |
| `docker` | Alternative Docker profile, with user-id mapping so containers write files as the host user. |

## Setting a new dataset

The two values that must be set for a new dataset are the mandatory `input`
(samplesheet path) and the reference `genome_species` / `genome_assembly`.
Everything else has a working default. Keep `transcript_level = true` for the
isoform-level goal.
