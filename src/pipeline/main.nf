#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------
// IMPORTS
// ----------------------------------------------------------------------------
include { require ; sendWebhook } from './utils/helpers'
include { printPipelineInfo } from './utils/init'

include { DOWNLOAD_READS } from './subworkflows/download'
include { PREPARE_INDEX } from './subworkflows/index'
include { PREPROCESSING } from './subworkflows/preprocessing.nf'


// ----------------------------------------------------------------------------
// MAIN ORCHESTRATOR
// ----------------------------------------------------------------------------
workflow {

    main:

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


    // ========================================================================
    // 3. EXECUTION ROUTING
    // ========================================================================

    if (params.step in ['download']) {
        DOWNLOAD_READS(params.srr_ids, params.dataset_dir)
    }

    if (params.step in ['index']) {

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
    }


    if (params.step in ['align']) {
        DOWNLOAD_READS(params.srr_ids, params.dataset_dir)

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

        PREPROCESSING(
            DOWNLOAD_READS.out,
            PREPARE_INDEX.out,
            params.preprocessing_dir,
            params.unfiltered_dir,
            params.scrnaseq_params,
            params.child_config,
        )
    }

    onComplete:
        def status = workflow.success ? 'SUCCESS' : 'FAILED'
        def duration = workflow.duration ?: 'Unknown duration'
        sendWebhook("Pipeline finished with status ${status}. Duration: ${duration}", status)

    onError:
            sendWebhook("Pipeline failed with error: ${workflow.errorMessage ?: 'Unknown error'}", 'error')

}
