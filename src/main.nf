#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------
// IMPORTS
// ----------------------------------------------------------------------------
include { ERR_MSG; sendWebhook } from './utils/helpers'
include { printPipelineInfo; validateParameters } from './utils/init'

include { DOWNLOAD_READS } from './subworkflows/download'
include { PREPARE_INDEX  } from './subworkflows/index'
include { ALIGN_READS    } from './subworkflows/align'
include { FILTER_MATRIX  } from './subworkflows/filter'

// ----------------------------------------------------------------------------
// PRE-FLIGHT INITIALIZATION
// ----------------------------------------------------------------------------
printPipelineInfo(params, launchDir, projectDir, workDir, workflow.profile)
validateParameters(params)

// ----------------------------------------------------------------------------
// MAIN ORCHESTRATOR
// ----------------------------------------------------------------------------
workflow {

    // Webhooks
    workflow.onComplete = { sendWebhook("Pipeline finished with status ${workflow.success ? 'SUCCESS' : 'FAILED'}. ${workflow.duration ? 'Duration: ' + workflow.duration : ''}", workflow.success ? 'success' : 'error') }
    workflow.onError = { sendWebhook("Pipeline failed with error: ${workflow.errorMessage ?: 'Unknown error'}", 'error') }

    // Channel initialization
    def fastq_files_channel = Channel.empty()
    def output_index_channel = Channel.empty()
    def raw_matrix_channel = Channel.empty()

    // 1. DOWNLOADING
    if (params.step in ['all', 'download']) {
        params.srr_ids ?: error(ERR_MSG('srr_ids'))
        DOWNLOAD_READS(params.srr_ids, params.dataset_dir)
        fastq_files_channel = DOWNLOAD_READS.out.fastq_files
    } else {
        fastq_files_channel = channel.fromFilePairs("${params.dataset_dir}/*/*_{1,2}.fastq.gz", size: 2)
            .ifEmpty { error("No FASTQ file pairs found matching: ${params.dataset_dir}/*/*_{1,2}.fastq.gz") }
            .map { id, files -> [id, files[0], files[1]] }
    }

    // 2. INDEXING
    if (params.step in ['all', 'index', 'align']) {
        PREPARE_INDEX()
        output_index_channel = PREPARE_INDEX.out.index_dir
    }

    // 3. ALIGNMENT
    if (params.step in ['all', 'align']) {
        params.genome_assembly ?: error(ERR_MSG('genome_assembly'))
        ALIGN_READS(fastq_files_channel, output_index_channel)
        raw_matrix_channel = ALIGN_READS.out.raw_matrix
    } else {
        raw_matrix_channel = channel.fromPath("${params.unfiltered_dir}/raw_matrix.seurat.rds")
    }

    // 4. QUALITY CONTROL
    if (params.step in ['all', 'filter']) {
        FILTER_MATRIX(raw_matrix_channel)
    }
}