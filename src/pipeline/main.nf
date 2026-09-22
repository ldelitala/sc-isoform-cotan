#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { require ; sendWebhook } from './utils/helpers'
include { printPipelineInfo } from './utils/init'

include { DOWNLOAD_READS } from './subworkflows/download'
include { PREPARE_INDEX } from './subworkflows/index'
include { PREPROCESSING } from './subworkflows/preprocessing.nf'

def success(msg) {
    sendWebhook(params.webhook_url, msg.toUpperCase(), "success")
}

def info(msg) {
    sendWebhook(params.webhook_url, msg.toUpperCase(), "info")
}

workflow {
    // ========================================================================
    // 1. FOL VALIDATION (Orchestrator Level)
    // ========================================================================
    def valid_steps = ['download', 'index', 'align']

    require(
        params.step != null && params.step in valid_steps,
        "Invalid or missing 'step' parameter. Provided: '${params.step}'. Must be one of: ${valid_steps.join(', ')}",
    )

    // ========================================================================
    // 2. PRE-FLIGHT INITIALIZATION
    // ========================================================================
    printPipelineInfo(params, launchDir, workDir, workflow.profile)
    success("Pipeline starting")

    // ========================================================================
    // 3. EXECUTION ROUTING
    // ========================================================================

    if (params.step == 'download') {
        DOWNLOAD_READS(params.input, params.dataset_dir)

        DOWNLOAD_READS.out.subscribe(
            onComplete: { info("Download complete") }
        )
    }

    if (params.step == 'index') {
        PREPARE_INDEX(
            params.skip_simpleaf,
            params.transcript_level,
            params.reference_dir,
            params.gene_index_dir,
            params.transcript_index_dir,
            params.genome_species,
            params.genome_assembly,
            params.ensembl_release,
        )


        PREPARE_INDEX.out.subscribe(
            onComplete: { info("Indexing complete") }
        )
    }

    if (params.step == 'align') {

        DOWNLOAD_READS(params.input, params.dataset_dir)

        def download_ch = DOWNLOAD_READS.out
            .collect()
            .map { items ->
                if (items) {
                    info("Download complete")
                }
                return items
            }
            .flatMap()

        PREPARE_INDEX(
            params.skip_simpleaf,
            params.transcript_level,
            params.reference_dir,
            params.gene_index_dir,
            params.transcript_index_dir,
            params.genome_species,
            params.genome_assembly,
            params.ensembl_release,
        )

        def index_ch = PREPARE_INDEX.out
            .collect()
            .map { items ->
                if (items) {
                    info("Indexing done")
                }
                return items
            }
            .flatMap()

        PREPROCESSING(
            download_ch,
            index_ch,
            params.preprocessing_dir,
            params.unfiltered_dir,
            params.scrnaseq_params,
            params.child_config,
            params.input,
        )

        PREPROCESSING.out.subscribe(
            onComplete: { info("Preprocessing complete") }
        )
    }

    // ========================================================================
    // 4. PIPELINE EVENT HANDLERS
    // ========================================================================
    
    // 1. Capture the parameter so it survives scope teardown
    def webhook_url = params.webhook_url
    
    // 2. Capture the workflow metadata object itself, again so it survives scope teardown
    def runMeta = workflow 

    workflow.onComplete {
        try {
            def isSuccess = runMeta.success
            def status = isSuccess ? 'success' : 'error'
            def msg = isSuccess ? "PIPELINE FINISHED" : "PIPELINE FAILED: ${runMeta.errorMessage ?: 'Unknown error'}"
            
            if (webhook_url) {
                sendWebhook(webhook_url, msg, status)
            }
        }
        catch (e) {
            log.warn("⚠️ Failed to send Discord notification: ${e.message}")
        }
    }
}
