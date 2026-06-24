include { ALIGN_SIMPLEAF } from '../modules/align'
include { QC_FILTER } from '../modules/filter'
include { ERR_MISS ; sendWebhook } from '../utils/helpers'

workflow PREPROCESSING {
    take:
    fastq_ch
    index_ch
    preprocessing_dir
    unfiltered_dir
    scrnaseq_params
    child_custom_config

    main:
    // fast check
    fastq_ch ?: ERR_MISS('fastq_ch')
    index_ch ?: ERR_MISS('index_ch')
    preprocessing_dir ?: ERR_MISS('preprocessing_dir')
    unfiltered_dir ?: ERR_MISS('unfiltered_dir')
    scrnaseq_params ?: ERR_MISS('scrnaseq_params')

    //begin
    def input_csv_ch = fastq_ch
        .map { srr_id, fq1, fq2 -> "sample_${srr_id},${fq1},${fq2}" }
        .collectFile(
            name: 'input.csv',
            storeDir: preprocessing_dir,
            newLine: true,
            seed: "sample,fastq_1,fastq_2",
            sort: true,
        )

    def raw_matrix_ch
    def raw_matrix_path = file(unfiltered_dir).resolve('raw_matrix.seurat.rds')
    
    if (!(raw_matrix_path.exists())) {
    
    ALIGN_SIMPLEAF(
        input_csv_ch,
        index_ch,
        unfiltered_dir,
        preprocessing_dir,
        scrnaseq_params,
        child_custom_config,
    )

    raw_matrix_ch = ALIGN_SIMPLEAF.out.raw_seurat_matrix
    
    }
    else {
        log.warn("\033[0;33mWARNING: Unfiltered matrix already exists at ${raw_matrix_path}. Skipping alignment step.\033[0m")
        raw_matrix_ch = channel.fromPath(raw_matrix_path)
    }

    raw_matrix_ch.tap { webhook_align_ch }
    webhook_align_ch.subscribe { sendWebhook("Alignment completed for dataset.", 'info') }

    QC_FILTER(raw_matrix_ch, index_ch.map { path -> file(path).resolve('mt_transcripts.txt').toString() })

    QC_FILTER.out.filtered_matrix.tap { webhook_qc_ch }
    webhook_qc_ch.subscribe { sendWebhook("Quality control filtering completed for dataset.", 'info') }

    emit:
    QC_FILTER.out.filtered_matrix
}
