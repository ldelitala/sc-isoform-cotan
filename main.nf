#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { CHECK_LAYOUT ; DOWNLOAD_BAM ; DOWNLOAD_FASTQ } from './modules/ingest'
include { ALIGN_SIMPLEAF } from './modules/align'
include { QC_FILTER } from './modules/filter'


workflow {

    // set up webhook notifications for pipeline completion and errors
    workflow.onComplete = { sendWebhook("Pipeline finished with status ${workflow.success ? 'SUCCESS' : 'FAILED'}. ${workflow.duration ? 'Duration: ' + workflow.duration : ''}") }
    workflow.onError = { sendWebhook("Pipeline failed with error: ${workflow.errorMessage ?: 'Unknown error'}") }

    // ANSI Colors for logging
    def c_reset = "\033[0m"
    def c_green = "\033[0;32m"
    def c_yellow = "\033[0;33m"
    def c_red = "\033[0;31m"

    // start of the pipeline
    params.dataset ?: error("${c_red}Parameter 'dataset' is required.${c_reset}")

    log.info("${c_green}=========================================${c_reset}")
    log.info("${c_green}Running pipeline for dataset: ${params.dataset}${c_reset}")
    log.info("${c_green}Pipeline step: ${params.step}${c_reset}")
    log.info("${c_green}=========================================${c_reset}")

    // 1. Validate local file inputs early
    //todo: add branch for creating the index if it does not exist
    if (params.step in ['all', 'align'] && (!params.genome || !file("${projectDir}/references/indices/${params.genome}_simpleaf").exists())) {
        error("${c_red}Pipeline error: 'genome' parameter missing or simpleaf index not found.${c_reset}")
    }

    if (params.step in ['all', 'filter'] && (!params.mt_transcripts || !file(params.mt_transcripts).exists())) {
        error("${c_red}Pipeline error: 'mt_transcripts' parameter missing or file not found.${c_reset}")
    }

    // Define channels for the workflow
    def fastq_files_channel
    // Sends the list of downloaded FASTQ files to the ALIGNMENT step
    def raw_matrix_channel
    // Sends the raw matrix output from ALIGNMENT to the QC step


    // 1. DOWNLOADING step
    if (params.step in ['all', 'download']) {
        params.srr_ids ?: error("${c_red}No SRR IDs provided. Use --srr_ids${c_reset}")

        def all_srrs = parseSrrIds(params.srr_ids) ?: error("${c_red}Pipeline error: No valid SRR IDs parsed from input: '${params.srr_ids}'${c_reset}")

        CHECK_LAYOUT(channel.fromList(all_srrs))

        def layout_branches = CHECK_LAYOUT.out
            .map { srr_id, layout -> [srr_id, layout.trim()] }
            .branch { _srr_id, layout ->
                single: layout == 'SINGLE'
                paired: layout == 'PAIRED'
                unknown: true
            }

        layout_branches.unknown.subscribe { srr_id, layout ->
            log.warn("${c_yellow}WARNING: Unknown layout '${layout}' detected for ${srr_id}. Skipping.${c_reset}")
        }

        DOWNLOAD_BAM(layout_branches.single.map { srr_id, _layout -> srr_id }, params.dataset)
        DOWNLOAD_FASTQ(layout_branches.paired.map { srr_id, _layout -> srr_id }, params.dataset)

        fastq_files_channel = DOWNLOAD_BAM.out
            .mix(DOWNLOAD_FASTQ.out)
            .tap { webhook_fastq_files_channel }

        webhook_fastq_files_channel.collect().subscribe { sendWebhook("Download step finished for dataset: ${params.dataset}") }
    }
    else {
        fastq_files_channel = channel.fromFilePairs("datasets/${params.dataset}/*/*_{1,2}.fastq.gz", size: 2)
            .map { id, files -> [id, files[0], files[1]] }
    }


    // 2. ALIGNMENT step
    if (params.step in ['all', 'align']) {

        //we create the run folder
        file("${projectDir}/runs/${params.dataset}_simpleaf").mkdirs()

        // we write the input.csv file
        def input_csv_channel = fastq_files_channel
            .ifEmpty { error("Pipeline error: No FASTQ files available. Either download failed, dataset folder is empty, or input path is incorrect.") }
            .map { srr_id, fq1, fq2 -> "sample_${srr_id},${fq1},${fq2}" }
            .collectFile(
                name: 'input.csv',
                storeDir: "${projectDir}/runs/${params.dataset}_simpleaf",
                newLine: true,
                seed: "sample,fastq_1,fastq_2",
                sort: true,
            )
            .tap { webhook_config_channel }

        //we write the nf-params.json file
        def params_json_channel = channel.fromPath(createParamsFile(params.dataset, params.scrnaseq_params))

        webhook_config_channel.subscribe { sendWebhook("nf-core/scrnaseq configuration files generated for dataset: ${params.dataset}") }

        ALIGN_SIMPLEAF(params.dataset, input_csv_channel, params_json_channel)

        raw_matrix_channel = ALIGN_SIMPLEAF.out.raw_seurat_matrix.tap { webhook_align_ch }

        webhook_align_ch.subscribe { sendWebhook("Alignment completed for dataset: ${params.dataset}") }
    }
    else {
        raw_matrix_channel = channel.fromPath("runs/${params.dataset}_simpleaf/results/simpleaf/mtx_conversions/combined_raw_matrix.seurat.rds")
    }

    // 4. QUALITY CONTROL
    if (params.step in ['all', 'filter']) {
        QC_FILTER(params.dataset, raw_matrix_channel.ifEmpty { error("Pipeline error: Raw Seurat matrix file not found. Either alignment failed or bypass path is incorrect.") }, channel.fromPath(params.mt_transcripts))
        QC_FILTER.out.filtered_matrix.subscribe { sendWebhook("Quality control filtering completed for dataset: ${params.dataset}") }
    }
}

// ----------------------------------------------------------------------------
// HELPER FUNCTIONS (Declarations must go at bottom of script)
// ----------------------------------------------------------------------------

def parseSrrIds(val) {
    if (!val) {
        return []
    }
    def m = (val =~ /^([A-Za-z]+)(\d+)\s*-\s*[A-Za-z]+(\d+)$/)
    if (m.matches()) {
        def prefix = m[0][1]
        def (start, end) = [m[0][2].toInteger(), m[0][3].toInteger()]
        return (start..end).collect { num -> prefix + num.toString().padLeft(m[0][2].length(), '0') }
    }
    return val.split(',').collect { srr -> srr.trim() }.findAll()
}

def sendWebhook(message) {
    if (params.webhook_url) {
        def payload = groovy.json.JsonOutput.toJson([content: message, text: message])
        try {
            ['curl', '-H', 'Content-Type: application/json', '-X', 'POST', '-d', payload, params.webhook_url].execute().waitFor()
        }
        catch (e: Exception) {
            log.warn("Webhook failed: ${e.message}")
        }
    }
}

def createParamsFile(dataset, scrnaseq_params) {
    def jsonFile = file("${projectDir}/runs/${dataset}_simpleaf/nf-params.json")
    jsonFile.parent.mkdirs()
    jsonFile.text = groovy.json.JsonOutput.prettyPrint(
        groovy.json.JsonOutput.toJson(
            [
                input: "input.csv",
                outdir: "results",
                simpleaf_index: file("${projectDir}/references/indices/${params.genome}_simpleaf/index").toString(),
            ] + scrnaseq_params
        )
    )
    return jsonFile
}
