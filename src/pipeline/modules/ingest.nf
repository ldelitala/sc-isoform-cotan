nextflow.enable.dsl = 2
// 1. Query the API
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
    curl -f -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${srr_id}&result=read_run&fields=library_layout" | tail -n +2 | cut -f2 | tr -d '\\n\\r'
    """
}

// 2a. The "SINGLE" track (downloads BAM and converts to FASTQs)
process DOWNLOAD_BAM {
    tag "${srr_id}"
    storeDir { "${dataset_dir}/${srr_id[-2..-1]}" }
    scratch '/dev/shm'
    errorStrategy 'retry'
    maxRetries 2

    input:
    val srr_id
    val dataset_dir

    output:
    tuple val(srr_id), path("${srr_id}_1.fastq.gz"), path("${srr_id}_2.fastq.gz")

    script:
    """
    set -eo pipefail
    prefetch --type TenX -q -X 100G "${srr_id}"
    bamtofastq --traceback --nthreads=${task.cpus} ${srr_id}/*.bam fastq_output

    # The final mv commands act as our safety net. 
    # If bamtofastq crashes, these files are never created, and storeDir knows to retry next time.
    mv fastq_output/*/*_R1_*.fastq.gz "${srr_id}_1.fastq.gz"
    mv fastq_output/*/*_R2_*.fastq.gz "${srr_id}_2.fastq.gz"
    """
}

// 2b. The "PAIRED" track (downloads SRA and extracts FASTQs)
process DOWNLOAD_FASTQ {
    tag "${srr_id}"
    storeDir { "${dataset_dir}/${srr_id[-2..-1]}" }
    scratch '/dev/shm'
    errorStrategy 'retry'
    maxRetries 2

    input:
    val srr_id
    val dataset_dir

    output:
    tuple val(srr_id), path("${srr_id}_1.fastq.gz"), path("${srr_id}_2.fastq.gz")

    script:
    """
    set -eo pipefail
    prefetch -q -X 100G "${srr_id}"
    
    # Dump directly from the prefetched folder
    fasterq-dump --split-files --include-technical --threads ${task.cpus} --temp . --outdir . "${srr_id}"
    
    # Compress all generated fastq files
    pigz -f -p ${task.cpus} *.fastq
    """
}