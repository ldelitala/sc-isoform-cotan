# 2. Cluster Resource & Thread Management

This document details the configuration limits, memory calculations, execution scheduling, and staging mechanics used to run the transcript scRNA-seq pipeline on the shared university machine (**Athena**: 88 CPU cores, 2.9TB RAM, ~1.4TB `/dev/shm` RAM disk).

---

## 1. Thread and Core Allocation

To maintain high throughput without locking up CPU cores, default resource limits in [nextflow.config](../nextflow.config) are configured to generic personal computer limits. High-performance configurations for the **Athena** server are decoupled and managed via the local `central.config` file.

### Overriding Resource Settings (Athena Overrides)
To run with maximum allocation on the Athena server, copy the resource blocks from `central.config.example` into your local `central.config` file. The local settings will override the defaults at runtime:

```groovy
// In central.config:
executor {
    name   = 'local'
    cpus   = 80
    memory = 2560.GB
}

process {
    resourceLimits = [ cpus: 80, memory: 2560.GB ]

    withName: 'DOWNLOAD_BAM|DOWNLOAD_FASTQ' {
        maxForks = 6        // Number of SRR IDs to download/extract concurrently
        cpus = 12           // Threads allocated to each fasterq-dump / pigz compression
    }

    withName: 'ALIGN_SIMPLEAF' {
        cpus   = 72
        memory = 2048.GB
    }

    withName: 'QC_FILTER' {
        cpus   = 8
        memory = 100.GB
    }
}
```

### CPU Thread Math (Worst-Case Scenario)
During Stage 1 (Downloads/Extraction), the maximum number of CPU cores active is calculated as:
$$\text{Max CPU Cores} = \text{maxForks} \times \text{cpus}$$
Using the default settings:
$$6 \text{ jobs} \times 12 \text{ threads} = 72 \text{ cores}$$
This leaves **16 cores** completely free for other users at all times during extraction.

---

## 2. Process Priority Scheduling (`nice` & `ionice`)

To ensure that other users do not experience system lag or input sluggishness even when the pipeline uses up to 72 cores, all CPU-intensive and I/O-intensive commands are systematically wrapped with priority scheduling.

Nextflow applies this to standard processes via the `beforeScript` configuration directive in [nextflow.config](../nextflow.config):

```groovy
process {
    beforeScript = 'renice -n 19 -p $$ && ionice -c 3 -p $$ || true'
}
```

* **CPU Priority (`nice -n 19` / `renice`)**: Sets process scheduling priority to the lowest possible level (niceness value 19). If another user launches a job, the OS scheduler immediately preempts our pipeline's threads.
* **Disk I/O Priority (`ionice -c 3`)**: Configures disk I/O scheduling to the "idle-only" class. The process will only access the hard drives for reading or writing when no other process is requesting disk I/O.

*Note for Native Exec Blocks*: Because native `exec:` blocks run Groovy code directly on the head node, they bypass the `beforeScript` task wrapper. To enforce resource politeness for the child workflow, the command string inside [align.nf](../modules/align.nf) is explicitly wrapped with priority constraints:
```groovy
def cmd_string = "... nice -n 19 ionice -c 3 nextflow run nf-core/scrnaseq ..."
```

---

## 3. RAM Disk Staging (`/dev/shm`) & Cleanup Traps

Tools like `prefetch`, `fasterq-dump`, and `bamtofastq` read and write tens of gigabytes of temporary data during extraction, creating severe I/O bottlenecks if run on standard hard drives.

### A. RAM Staging & Zero-Disk Download
To protect the persistent hard drives of the shared server from excessive wear and space warnings, we download the raw files (`.sra` and `.bam`) directly into the `/dev/shm` RAM disk. 
* Downloads happen entirely in RAM.
* `fasterq-dump` and `bamtofastq` read directly from RAM.
* Reconstructed FASTQ files are compressed in RAM.
* Only the final compressed FASTQ files are moved to persistent storage.

### B. Trap-Based RAM Leak Prevention
If a job fails or is aborted, any files left in `/dev/shm` will permanently consume physical RAM. To prevent this, both [download_fastq.sh](../scripts/stage1_download/download_fastq.sh) and [download_bam.sh](../scripts/stage1_download/download_bam.sh) register Bash **exit trap handlers**:

```bash
# Define temp path inside RAM disk
TEMP_DIR="/dev/shm/deli_${SRR}"
mkdir -p "${TEMP_DIR}"
trap 'rm -rf "${TEMP_DIR}"' EXIT INT TERM
```
This guarantees that all RAM-allocated temporary files (including downloaded SRA and BAM files) are immediately and completely deleted under any exit condition.
