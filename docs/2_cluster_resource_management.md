# 2. Cluster Resource & Thread Management

This document details the configuration limits, memory calculations, execution scheduling, and staging mechanics used to run the transcript scRNA-seq pipeline on the shared university machine (**Athena**: 88 CPU cores, 2.9TB RAM, ~1.4TB `/dev/shm` RAM disk).

---

## 1. Thread and Core Allocation

To maintain high throughput without locking up all CPU cores, resources are capped at the process levels inside [nextflow.config](file:///home/deli/athena_mount/nextflow.config).

### Configuration Settings
Limits are defined inside the `process` configuration block:
```groovy
process {
    // Limits applied per process
    withName: INGEST_SRA {
        maxForks = 6        // Number of SRR IDs to download/extract concurrently
        cpus = 12           // Threads allocated to each fasterq-dump / pigz compression
    }

    withName: ALIGN_SIMPLEAF {
        cpus = 72           // Nextflow CPU core limit (polite limit for 88 cores)
        memory = '2.0 TB'   // Nextflow memory limit (polite limit for 2.9TB RAM)
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

Nextflow applies this globally to every process via the `beforeScript` configuration directive in [nextflow.config](file:///home/deli/athena_mount/nextflow.config):

```groovy
process {
    beforeScript = 'nice -n 19 ionice -c 3'
}
```

* **CPU Priority (`nice -n 19`)**: Sets process scheduling priority to the lowest possible level (niceness value 19). If another user launches a job, the OS scheduler immediately preempts our pipeline's threads.
* **Disk I/O Priority (`ionice -c 3`)**: Configures disk I/O scheduling to the "idle-only" class. The process will only access the hard drives for reading or writing when no other process is requesting disk I/O.

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
If a job fails or is aborted, any files left in `/dev/shm` will permanently consume physical RAM. To prevent this, both [download_fastq.sh](file:///home/deli/athena_mount/scripts/stage1_download/download_fastq.sh) and [download_bam.sh](file:///home/deli/athena_mount/scripts/stage1_download/download_bam.sh) register Bash **exit trap handlers**:

```bash
# Define temp path inside RAM disk
TEMP_DIR="/dev/shm/deli_${SRR}"
mkdir -p "${TEMP_DIR}"
trap 'rm -rf "${TEMP_DIR}"' EXIT INT TERM
```
This guarantees that all RAM-allocated temporary files (including downloaded SRA and BAM files) are immediately and completely deleted under any exit condition.
