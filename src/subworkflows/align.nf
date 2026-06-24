include { ALIGN_SIMPLEAF } from '../modules/align'
include { sendWebhook } from '../utils/helpers'

workflow ALIGN_READS {
    take:
        fastq_ch
        index_ch
        
    main:
        def input_csv_ch = fastq_ch
            .map { srr_id, fq1, fq2 -> "sample_${srr_id},${fq1},${fq2}" }
            .collectFile(
                name: 'input.csv',
                storeDir: params.preprocessing_dir,
                newLine: true,
                seed: "sample,fastq_1,fastq_2",
                sort: true,
            )
            .tap { webhook_config_channel }

        webhook_config_channel.subscribe { sendWebhook("nf-core/scrnaseq configuration files generated for dataset", 'info') }

        ALIGN_SIMPLEAF(input_csv_ch, index_ch, params.unfiltered_dir, params.preprocessing_dir, params.scrnaseq_params, params.child_custom_config)

        def raw_matrix_ch = ALIGN_SIMPLEAF.out.raw_seurat_matrix.tap { webhook_align_ch }
        webhook_align_ch.subscribe { sendWebhook("Alignment completed for dataset.", 'info') }

    emit:
        raw_matrix = raw_matrix_ch
}