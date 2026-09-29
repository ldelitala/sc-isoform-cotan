#!/bin/bash
# Usage: ./download_fastq.sh <srr_id> <cpus>
set -euo pipefail

srr_id=$1
cpus=$2

prefetch -q -X 100G "${srr_id}"

# Dump and compress
fasterq-dump --split-files --include-technical --threads "${cpus}" --temp . --outdir . "${srr_id}"

pigz -f -p "${cpus}" *.fastq