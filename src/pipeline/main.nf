#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { require ; sendWebhook } from './utils/helpers'
include { printPipelineInfo } from './utils/init'

include { DOWNLOAD_READS } from './subworkflows/download'
include { PREPARE_INDEX } from './subworkflows/index'
include { PREPROCESSING } from './subworkflows/preprocessing.nf'

def success(msg) {
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
            onComplete: { success("Download complete") }
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
            onComplete: { success("Download complete") }
        )
    }

    if (params.step == 'align') {
        
        DOWNLOAD_READS(params.input, params.dataset_dir)

        def download_ch = DOWNLOAD_READS.out
            .collect()
            .map { _items ->
                success("Download complete")
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
            .map { _items ->
                    success("Indexing done")
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
            onComplete: { success("Download complete") }
        )
    }

    def webhook_url = params.webhook_url

    workflow.onComplete {
        try {
            sendWebhook(webhook_url, "PIPELINE FINISHED", 'error')
        }
        catch (e) {
            log.warn("⚠️ Failed to send Discord onComplete notification: ${e.message}")
        }
    }

    workflow.onError {
        try {
            sendWebhook(webhook_url, "PIPELINE FAILED", 'error')
        }
        catch (e) {
            log.warn("⚠️ Pipeline failed, and also failed to send Discord error alert: ${e.message}")
        }
    }
}
