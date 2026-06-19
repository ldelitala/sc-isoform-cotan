nextflow.enable.dsl = 2

// 1. Query the API (Ultra-lightweight process)
process CHECK_LAYOUT {
    tag "${srr_id}"
    errorStrategy 'retry'
    maxRetries 3

    input:
    val srr_id

    output:
    tuple val(srr_id), stdout

    script:
    """
    set -eo pipefail
    curl -f -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${srr_id}&result=read_run&fields=library_layout" | tail -n +2 | cut -f2 | tr -d '\\n\\r'
    """
}

// 2a. The "SINGLE" track (downloads BAM and converts to FASTQs)
process DOWNLOAD_BAM {
    tag "${srr_id}"
    storeDir { "datasets/${dataset}/${srr_id[-2..-1]}" }
    scratch '/dev/shm'
    errorStrategy 'retry'
    maxRetries 2

    input:
    val srr_id
    val dataset

    output:
    tuple val(srr_id), path("${srr_id}_1.fastq.gz"), path("${srr_id}_2.fastq.gz")

    script:
    """
    set -eo pipefail
    prefetch --type TenX -q -X 100G "${srr_id}"
    BAM_FILE=\$(find "${srr_id}" -maxdepth 1 -name "*.bam" | head -n 1)
    if [ -z "\${BAM_FILE}" ]; then
        echo "Error: BAM file not found" >&2
        exit 1
    fi
    bamtofastq --traceback --nthreads="${task.cpus}" "\${BAM_FILE}" fastq_output

    # Rename and move files to task work directory so nextflow can stage out
    mv \$(find fastq_output -name "*_R1_*.fastq.gz" | head -n 1) "${srr_id}_1.fastq.gz"
    mv \$(find fastq_output -name "*_R2_*.fastq.gz" | head -n 1) "${srr_id}_2.fastq.gz"
    """
}

// 2b. The "PAIRED" track (downloads SRA and extracts FASTQs)
process DOWNLOAD_FASTQ {
    tag "${srr_id}"
    storeDir { "datasets/${dataset}/${srr_id[-2..-1]}" }
    scratch '/dev/shm'
    errorStrategy 'retry'
    maxRetries 2

    input:
    val srr_id
    val dataset

    output:
    tuple val(srr_id), path("${srr_id}_1.fastq.gz"), path("${srr_id}_2.fastq.gz")

    script:
    """
    set -eo pipefail
    prefetch --output-directory . -q -X 100G "${srr_id}"
    fasterq-dump --split-files --threads "${task.cpus}" --temp . --outdir . "${srr_id}/${srr_id}.sra"
    pigz -f -p "${task.cpus}" "${srr_id}"*.fastq
    """
}
