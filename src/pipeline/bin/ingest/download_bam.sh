#!/bin/bash
# Usage: ./download_bam.sh <srr_id> <cpus>
set -euo pipefail

srr_id=$1
cpus=$2

prefetch --type TenX -q -X 100G "${srr_id}"
bamtofastq --traceback --nthreads="${cpus}" "${srr_id}"/*.bam fastq_output

# Move to expected filenames
mv fastq_output/*/*_R1_*.fastq.gz "${srr_id}_1.fastq.gz"
mv fastq_output/*/*_R2_*.fastq.gz "${srr_id}_2.fastq.gz"