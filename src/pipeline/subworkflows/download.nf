include { CHECK_LAYOUT ; DOWNLOAD_BAM ; DOWNLOAD_FASTQ } from '../modules/ingest'
include { require ; ensureDir ; sendWebhook } from '../utils/helpers'

// ========================================================================
// LIGHTWEIGHT LOGGING PROCESS (Replaces .subscribe)
// ========================================================================
// Because this uses 'exec:', it runs instantly in the JVM. It does not 
// spawn an OS task, it doesn't create a work/ directory, but it explicitly 
// consumes the channel so Nextflow can safely shut down.
process LOG_UNKNOWN_LAYOUT {
    input:
    tuple val(srr_id), val(layout)

    exec:
    log.warn("\033[0;33mWARNING: Unknown layout '${layout}' detected for ${srr_id}. Skipping.\033[0m")
}

/*
 * SUBWORKFLOW: DOWNLOAD_READS
 * * Description:
 * Orchestrates the downloading of raw sequencing reads from the SRA database. 
 * Uses the dataset dir as cache with storeDir to avoid re-downloading files.
 */
workflow DOWNLOAD_READS {
    take:
    input
    dataset_dir

    main:
    
    // ========================================================================
    // 1. FOL VALIDATION (Declarative Contract)
    // ========================================================================

    // Base Requirements (Existence)
    require( [input, dataset_dir].every { p -> p != null }, 
        "Mandatory parameters 'input' and 'dataset_dir' must be provided." )

    def input_file = file(input)
    require( input_file.exists(), 
        "Samplesheet file not found at: ${input}" )

    // Data Integrity (Parsing & Logic)
    def all_srrs = []
    input_file.splitCsv(header: true).each { row ->
        if (row.sra) {
            all_srrs << row.sra.trim()
        }
    }
    all_srrs = all_srrs.unique()

    require( all_srrs.size() > 0, 
        "No valid SRA run IDs found in 'input' parameter: ${input}" )

    // File System Integrity (State Check)
    ensureDir(dataset_dir, "dataset")

    // ========================================================================
    // 2. EXECUTION
    // ========================================================================

    CHECK_LAYOUT(channel.fromList(all_srrs))

    def layout_branches = CHECK_LAYOUT.out
        .map { srr_id, layout -> [srr_id, layout.trim()] }
        .branch { _srr_id, layout ->
            single: layout == 'SINGLE'
            paired: layout == 'PAIRED'
            unknown: true
        }

    LOG_UNKNOWN_LAYOUT(layout_branches.unknown)

    DOWNLOAD_BAM(layout_branches.single.map { srr_id, _layout -> srr_id }, dataset_dir)
    DOWNLOAD_FASTQ(layout_branches.paired.map { srr_id, _layout -> srr_id }, dataset_dir)

    def fastq_ch = DOWNLOAD_BAM.out
        .mix(DOWNLOAD_FASTQ.out)
        .ifEmpty { error("Pipeline error: No FASTQ files available. Download failed.") }
    

    emit:
    // identity mapping used to suppress annoying vs code parser warning
    fastq_ch.map { x -> x }
}