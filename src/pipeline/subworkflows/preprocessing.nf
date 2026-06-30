include { ALIGN_SIMPLEAF } from '../modules/align'
include { QC_FILTER } from '../modules/filter'
include {  require ; sendWebhook } from '../utils/helpers'

//TODO: i'm using this only for transcript level case but in the future i have to fix mt_transcript.txt missing in gene index for gene_level case.
workflow PREPROCESSING {

    take:
    fastq_ch
    index_ch
    preprocessing_dir
    unfiltered_dir
    scrnaseq_params
    child_custom_config


    main:

    // ========================================================================
    // 1. FOL VALIDATION (Static Contract)
    // ========================================================================

    // Base Requirements (Existence)
    require( [fastq_ch, index_ch, preprocessing_dir, unfiltered_dir, scrnaseq_params].every { p -> p != null }, 
        "Mandatory parameters are missing for the PREPROCESSING subworkflow." )

    // File System Integrity (Static State Check)
    require( [preprocessing_dir, unfiltered_dir].every { d -> file(d).getParent()?.exists() }, 
        "Parent directories for 'preprocessing_dir' or 'unfiltered_dir' do not exist. Cannot write outputs." )

    // ========================================================================
    // 2. EXECUTION & ASYNCHRONOUS VALIDATION
    // ========================================================================
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
    webhook_align_ch.collect().subscribe { sendWebhook("Alignment completed for dataset.", 'info') }

    // Intercept the index channel to validate the existence of mt_transcripts.txt before QC
    def mt_transcripts_ch = index_ch.map { idx_path -> 
        def mt_file = file(idx_path).resolve('mt_transcripts.txt')
        if (!mt_file.exists()) {
            error("\033[0;31mPipeline Validation Error: Required file 'mt_transcripts.txt' not found inside index directory: ${idx_path}\033[0m")
        }
        return mt_file.toString()
    }

    QC_FILTER(raw_matrix_ch, mt_transcripts_ch)

    QC_FILTER.out.filtered_matrix.tap { webhook_qc_ch }
    webhook_qc_ch.collect().subscribe { sendWebhook("Quality control filtering completed for dataset.", 'info') }

    emit:
    QC_FILTER.out.filtered_matrix
}
