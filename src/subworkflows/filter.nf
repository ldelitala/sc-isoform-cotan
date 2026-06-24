include { QC_FILTER } from '../modules/filter'
include { sendWebhook } from '../utils/helpers'

workflow FILTER_MATRIX {
    take:
        raw_matrix_ch
        
    main:
        QC_FILTER(raw_matrix_ch.ifEmpty { error("Pipeline error: Raw Seurat matrix file not found.") })
        QC_FILTER.out.filtered_matrix.subscribe { sendWebhook("Quality control filtering completed for dataset.", 'info') }
}