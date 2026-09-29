//TODO: Change the dataset dir structure so that it is dataset_dir/sample_name/srr_ids
// so for example dataset/sample_1/02, dataset/sample_1/03, dataset/sample_2/04, dataset/sample_2/05, ...
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
    1.1_ingest_check_layout.sh ${srr_id}
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
    1.2_ingest_download_bam.sh ${srr_id} ${task.cpus}
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
    1.3_ingest_download_fastq.sh ${srr_id} ${task.cpus}
    """
}