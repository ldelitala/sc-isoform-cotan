#!/bin/bash

# run_pipeline.sh
# Usage: ./run_pipeline.sh <dataset_name> <genome_code> <protocol>
# Example: ./run_pipeline.sh Arrigoni2023 GRCh38 10XV3

set -euo pipefail

# Force Nextflow to use the permissive v1 parser (fixes strict v2 parser bug in Nextflow 26.x with relative config includes)
export NXF_SYNTAX_PARSER=v1

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <dataset_name> <genome_code> <protocol>"
    exit 1
fi

DATASET_NAME=$1
GENOME_CODE=$2
PROTOCOL=$3

# Project root path (absolute path of grandparent directory of scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

# Validate that the dataset directory exists (must match case-sensitive folder name in datasets/)
DATASET_DIR="${PROJECT_ROOT}/datasets/${DATASET_NAME}"
if [ ! -d "${DATASET_DIR}" ]; then
    echo "Error: Dataset directory not found at: ${DATASET_DIR}"
    echo "The <dataset_name> argument must match the folder name inside datasets/ exactly (case-sensitive)."
    exit 1
fi

# Define run name (datasetname_pipe1) in lowercase
RUN_NAME_LOWER=$(echo "${DATASET_NAME}" | tr '[:upper:]' '[:lower:]')
RUN_NAME="${RUN_NAME_LOWER}_pipe1"

METADATA_DIR="${PROJECT_ROOT}/metadata/${RUN_NAME}"
RUN_DIR="${PROJECT_ROOT}/runs/${RUN_NAME}"

echo "========================================="
echo "Initializing Pipeline Run: ${RUN_NAME}"
echo "Genome: ${GENOME_CODE}"
echo "Protocol: ${PROTOCOL}"
echo "Metadata Dir: ${METADATA_DIR}"
echo "Run Dir: ${RUN_DIR}"
echo "========================================="

# 1. Create metadata directory
mkdir -p "${METADATA_DIR}"

# 2. Automatically generate multi-sample input.csv
echo "sample,fastq_1,fastq_2" > "${METADATA_DIR}/input.csv"
SAMPLE_COUNT=0

# Loop through sample folders in datasets
for sample_dir in "${PROJECT_ROOT}/datasets/${DATASET_NAME}"/*; do
    if [ -d "${sample_dir}" ] && [ "$(basename "${sample_dir}")" != "README.md" ]; then
        SAMPLE_ID=$(basename "${sample_dir}")
        
        # Locate FASTQ files (supporting both _1.fastq.gz and _R1.fastq.gz naming conventions)
        FASTQ_1=$(ls "${sample_dir}"/*_1.fastq.gz "${sample_dir}"/*_R1*.fastq.gz 2>/dev/null | head -n 1 || true)
        FASTQ_2=$(ls "${sample_dir}"/*_2.fastq.gz "${sample_dir}"/*_R2*.fastq.gz 2>/dev/null | head -n 1 || true)
        
        if [ -n "${FASTQ_1}" ] && [ -n "${FASTQ_2}" ]; then
            echo "sample_${SAMPLE_ID},${FASTQ_1},${FASTQ_2}" >> "${METADATA_DIR}/input.csv"
            SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
        fi
    fi
done

if [ "${SAMPLE_COUNT}" -eq 0 ]; then
    echo "Error: No samples with FASTQ files found under datasets/${DATASET_NAME}/"
    exit 1
fi

echo "Generated input.csv with ${SAMPLE_COUNT} samples:"
echo "----------------------------------------"
cat "${METADATA_DIR}/input.csv"
echo "----------------------------------------"

# 3. Generate nf-params.json inside metadata directory
cat <<EOF > "${METADATA_DIR}/nf-params.json"
{
    "input": "input.csv",
    "outdir": "results",
    "protocol": "${PROTOCOL}",
    "skip_cellbender": true,
    "simpleaf_index": "${PROJECT_ROOT}/references/indices/${GENOME_CODE}_simpleaf",
    "simpleaf_umi_resolution": "parsimony-em"
}
EOF

# 4. Set up runs directory and symlinks
mkdir -p "${RUN_DIR}"
ln -sf "${METADATA_DIR}/input.csv" "${RUN_DIR}/input.csv"
ln -sf "${METADATA_DIR}/nf-params.json" "${RUN_DIR}/nf-params.json"
ln -sf "${PROJECT_ROOT}/nextflow.config" "${RUN_DIR}/nextflow.config"

# 5. Execute nextflow
cd "${RUN_DIR}"
echo "Starting Nextflow pipeline run..."

# Run Nextflow with reporting flags enabled (no -name flag to prevent duplicate name crashes)
if nice -n 18 nextflow run nf-core/scrnaseq \
    -r 4.1.0 \
    -profile singularity \
    -resume \
    -params-file nf-params.json \
    -with-report results/pipeline_info/report.html \
    -with-timeline results/pipeline_info/timeline.html \
    -with-trace results/pipeline_info/trace.txt; then

    echo "Pipeline execution finished successfully!"
    echo "Cleaning up intermediate Nextflow work directory to save disk space..."
    rm -rf work/
else
    echo "Error: Nextflow pipeline failed. Preserving work/ directory for resuming (-resume)."
    exit 1
fi

echo "Outputs saved to: ${RUN_DIR}/results/"
