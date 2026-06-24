include { CHECK_LAYOUT ; DOWNLOAD_BAM ; DOWNLOAD_FASTQ } from '../modules/ingest'
include { ERR_MISS; parseSrrIds ; sendWebhook } from '../utils/helpers'

/*
 * SUBWORKFLOW: DOWNLOAD_READS
 * * Description:
 * Orchestrates the downloading of raw sequencing reads from the SRA database. 
 * Uses the dataset dir as cache with storeDir to avoid re-downloading files.
 */
workflow DOWNLOAD_READS {
    take:
    srr_ids
    dataset_dir

    main:
    
    // fast check 
    srr_ids ?: ERR_MISS ('srr_ids')
    dataset_dir ?: ERR_MISS ('dataset_dir')
    def all_srrs = parseSrrIds(srr_ids) ?: error("No valid SRA run IDs found in 'srr_ids' parameter: ${srr_ids}")
    
    // begin
    CHECK_LAYOUT(channel.fromList(all_srrs))

    def layout_branches = CHECK_LAYOUT.out
        .map { srr_id, layout -> [srr_id, layout.trim()] }
        .branch { _srr_id, layout ->
            single: layout == 'SINGLE'
            paired: layout == 'PAIRED'
            unknown: true
        }

    layout_branches.unknown.subscribe { srr_id, layout ->
        log.warn("\033[0;33mWARNING: Unknown layout '${layout}' detected for ${srr_id}. Skipping.\033[0m")
    }

    DOWNLOAD_BAM(layout_branches.single.map { srr_id, _layout -> srr_id }, dataset_dir)
    DOWNLOAD_FASTQ(layout_branches.paired.map { srr_id, _layout -> srr_id }, dataset_dir)

    def fastq_ch = DOWNLOAD_BAM.out
        .mix(DOWNLOAD_FASTQ.out)
        .ifEmpty { error("Pipeline error: No FASTQ files available. Download failed.") }
        .tap { webhook_fastq_files_channel }

    webhook_fastq_files_channel.collect().subscribe { sendWebhook("Download step finished for dataset.", 'info') }

    emit:
    //identity mapping used to suppress annoyng vs code parser warning
    fastq_ch.map { x -> x }
}
