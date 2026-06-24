#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------
// IMPORTS
// ----------------------------------------------------------------------------
include { sendWebhook } from './utils/helpers'
include { printPipelineInfo } from './utils/init'

include { DOWNLOAD_READS } from './subworkflows/download'
include { PREPARE_INDEX  } from './subworkflows/index'
include { PREPROCESSING } from './subworkflows/preprocessing.nf'

// ----------------------------------------------------------------------------
// PRE-FLIGHT INITIALIZATION
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// MAIN ORCHESTRATOR
// ----------------------------------------------------------------------------
workflow {

    printPipelineInfo(params, launchDir, workDir, workflow.profile)

    // Webhooks
    workflow.onComplete = { sendWebhook("Pipeline finished with status ${workflow.success ? 'SUCCESS' : 'FAILED'}. ${workflow.duration ? 'Duration: ' + workflow.duration : ''}", workflow.success ? 'success' : 'error') }
    workflow.onError = { sendWebhook("Pipeline failed with error: ${workflow.errorMessage ?: 'Unknown error'}", 'error') }

    if(params.steps in ['download']){
        DOWNLOAD_READS(params.srr_ids, params.dataset_dir)
    }
    
    if(params.step in ['index']){

        PREPARE_INDEX(
            params.skip_simpleaf, 
            params.transcript_level, 
            params.reference_dir, 
            params.gene_index_dir, 
            params.transcript_index_dir, 
            params.genome_species, 
            params.genome_assembly, 
            params.ensembl_release
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
            params.ensembl_release
            )

        PREPROCESSING(
            DOWNLOAD_READS.out,
            PREPARE_INDEX.out, 
            params.preprocessing_dir, 
            params.unfiltered_dir, 
            params.scrnaseq_params, 
            params.child_config)
    }

}