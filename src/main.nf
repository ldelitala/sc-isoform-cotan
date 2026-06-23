#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { CHECK_LAYOUT ; DOWNLOAD_BAM ; DOWNLOAD_FASTQ } from './modules/ingest'
include { DOWNLOAD_REFERENCE ; BUILD_INDEX ; APPLY_TRANSCRIPT_CHEAT } from './modules/index'
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

    log.info(
        """
    ${c_green}========================================================================${c_reset}
    ${c_green}P I P E L I N E   E X E C U T I O S   I N F O R M A T I O N${c_reset}
    ${c_green}========================================================================${c_reset}
    * Dataset Directory   : ${params.dataset_dir ?: 'Not provided'}
    * Pipeline Step       : ${params.step}
    * SRA Run IDs         : ${params.srr_ids ?: 'Not provided'}
    * Genome Assembly     : ${params.genome_assembly ?: 'Not provided'}
    * Genome Species      : ${params.genome_species ?: 'None'}
    * SimpleAF Index Path : ${params.index_dir ?: 'Not provided'}
    * Transcript Level    : ${params.transcript_level}
    
    [Directories]
    * Reference Dir       : ${params.reference_dir}
    * Index Dir           : ${params.index_dir}
    * Preprocessing Dir   : ${params.preprocessing_dir}
    * Unfiltered Dir      : ${params.unfiltered_dir}
    * Filtered Dir        : ${params.filtered_dir}
    
    [QC Thresholds]
    * Min Features        : ${params.min_features}
    * Max Features        : ${params.max_features}
    * Min Counts          : ${params.min_counts}
    * Max Percent MT      : ${params.max_percent_mt}
    * Mitochondrial file  : ${params.containsKey('mt_transcripts') ? params.mt_transcripts : 'Not configured'}
    
    [Downstream Aligner]
    * Protocol            : ${params.scrnaseq_params.protocol ?: 'Not configured'}
    * Skip CellBender     : ${params.scrnaseq_params.skip_cellbender}
    * UMI Resolution      : ${params.scrnaseq_params.simpleaf_umi_resolution}
    
    [Execution Context]
    * Launch Directory    : ${launchDir}
    * Project Directory   : ${projectDir}
    * Work Directory      : ${workDir}
    * Profile             : ${workflow.profile}
    ${c_green}========================================================================${c_reset}
    """
    )

    // ----------------------------------------------------------------------------
    // Hardening Validations & Helper Determinations
    // ----------------------------------------------------------------------------

    if (params.step in ['all', 'download']) {
        validateDirectoryWritable(params.dataset_dir, 'dataset_dir')
    }
    if (params.step in ['all', 'index']) {
        validateDirectoryWritable(params.reference_dir, 'reference_dir')
        if (!params.skip_simpleaf) {
            validateDirectoryWritable(params.index_dir, 'index_dir')
        }
    }
    if (params.step in ['all', 'align']) {
        validateDirectoryWritable(params.preprocessing_dir, 'preprocessing_dir')
        validateDirectoryWritable(params.unfiltered_dir, 'unfiltered_dir')
        if (params.skip_simpleaf) {
            validatePiscemIndex(params.index_dir)
        }
    }
    if (params.step in ['all', 'filter']) {
        validateDirectoryWritable(params.filtered_dir, 'filtered_dir')
    }


    // Define channels for the workflow
    def fastq_files_channel
    def output_index_channel = Channel.empty()
    def raw_matrix_channel


    // 1. DOWNLOADING step
    if (params.step in ['all', 'download']) {

        params.srr_ids ?: error(ERR_MSG('srr_ids'))

        def all_srrs = parseSrrIds(params.srr_ids) ?: error("No valid SRA run IDs found in 'srr_ids' parameter: ${params.srr_ids}")

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

        DOWNLOAD_BAM(layout_branches.single.map { srr_id, _layout -> srr_id }, params.dataset_dir)
        DOWNLOAD_FASTQ(layout_branches.paired.map { srr_id, _layout -> srr_id }, params.dataset_dir)

        fastq_files_channel = DOWNLOAD_BAM.out
            .mix(DOWNLOAD_FASTQ.out)
            .ifEmpty { error("Pipeline error: No FASTQ files available. Download failed.") }
            .tap { webhook_fastq_files_channel }

        webhook_fastq_files_channel.collect().subscribe { sendWebhook("Download step finished for dataset.") }
    }
    else {
        fastq_files_channel = channel.fromFilePairs("${params.dataset_dir}/*/*_{1,2}.fastq.gz", size: 2)
            .ifEmpty {
                error(
                    "No FASTQ file pairs found matching: ${params.dataset_dir}/*/*_{1,2}.fastq.gz\n" + "Please check that the path is correct and the files are named properly."
                )
            }
            .map { id, files -> [id, files[0], files[1]] }
    }

    // 2. INDEXING step
    if (params.step in ['all', 'index', 'align']) {

        if (!params.skip_simpleaf) {
            DOWNLOAD_REFERENCE(
                params.reference_dir,
                params.reference_urls,
                params.genome_species,
                params.genome_assembly,
                params.ensembl_release,
            )
            log.info("${c_green}Starting SimpleAF index building...${c_reset}")
            output_index_channel = BUILD_INDEX(DOWNLOAD_REFERENCE.out, params.index_dir)
        }
        else {
            log.info("${c_yellow}Skipping SimpleAF index building...${c_reset}")
            // Ensure this points to the parent directory containing the index folder
            output_index_channel = channel.fromPath(params.index_dir)
                .ifEmpty { error("Pipeline error: Index not found at ${params.index_dir}") }
        }

        // Apply the cheat if needed, using the unified channel
        if (params.transcript_level.toString().toBoolean()) {
            output_index_channel = APPLY_TRANSCRIPT_CHEAT(output_index_channel, file(params.index_dir).getParent())
        }

        // Map output channel to its absolute path string to bypass exec: staging limitations
        output_index_channel = output_index_channel.map { it.toAbsolutePath().toString() }
    }

    // 3. ALIGNMENT step
    if (params.step in ['all', 'align']) {

        params.genome_assembly ?: error(ERR_MSG('genome_assembly'))

        // we write the input.csv file
        def input_csv_channel = fastq_files_channel
            .map { srr_id, fq1, fq2 -> "sample_${srr_id},${fq1},${fq2}" }
            .collectFile(
                name: 'input.csv',
                storeDir: params.preprocessing_dir,
                newLine: true,
                seed: "sample,fastq_1,fastq_2",
                sort: true,
            )
            .tap { webhook_config_channel }

        webhook_config_channel.subscribe { sendWebhook("nf-core/scrnaseq configuration files generated for dataset") }

        ALIGN_SIMPLEAF(input_csv_channel, output_index_channel)

        raw_matrix_channel = ALIGN_SIMPLEAF.out.raw_seurat_matrix.tap { webhook_align_ch }

        webhook_align_ch.subscribe { sendWebhook("Alignment completed for dataset.") }
    }
    else {
        raw_matrix_channel = channel.fromPath("${params.unfiltered_dir}/raw_matrix.seurat.rds")
    }

    // 4. QUALITY CONTROL
    if (params.step in ['all', 'filter']) {
        QC_FILTER(raw_matrix_channel.ifEmpty { error("Pipeline error: Raw Seurat matrix file not found. Either alignment failed or bypass path is incorrect.") }, channel.fromPath(params.mt_transcripts))
        QC_FILTER.out.filtered_matrix.subscribe { sendWebhook("Quality control filtering completed for dataset.") }
    }
}

// ----------------------------------------------------------------------------
// HELPER FUNCTIONS (Declarations must go at bottom of script)
// ----------------------------------------------------------------------------

// Global validation error message handler
def ERR_MSG(param) {
    return "\033[0;31mPipeline error: '${param}' parameter missing.\033[0m"
}

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


// Hard validation of Piscem or Salmon simpleaf index contents
def validatePiscemIndex(index_dir) {
    if (!index_dir) {
        error("Validation Error: 'index_dir' is required but not configured.")
    }
    def index_path = file(index_dir)
    if (!index_path.exists()) {
        error("Validation Error: Specified index path does not exist: ${index_dir}")
    }
    def nested_index = file("${index_dir}/index")
    def has_t2g = file("${index_path}/t2g_3col.tsv").exists() || file("${nested_index}/t2g_3col.tsv").exists()
    def has_piscem = file("${index_path}/piscem_idx.ssi").exists() || file("${nested_index}/piscem_idx.ssi").exists()
    def has_salmon = file("${index_path}/ref_core.hash").exists() || file("${nested_index}/ref_core.hash").exists()

    if (!has_t2g || !(has_piscem || has_salmon)) {
        error("Validation Error: Malformed simpleaf index at ${index_dir}. Missing required index files (t2g_3col.tsv and index binaries).")
    }
}

def validateDirectoryWritable(dir_path, param_name) {
    if (!dir_path) {
        error("Validation Error: Parameter '${param_name}' is empty.")
    }
    def target = file(dir_path)

    // Linearly check target -> check parent -> check grandparent
    def check_dir = target.exists() ? target : target.getParent()
    if (check_dir != null && !check_dir.exists()) {
        check_dir = check_dir.getParent()
    }

    if (check_dir == null || !check_dir.exists() || !check_dir.toFile().canWrite()) {
        error("Validation Error: Target path or its parent is not writable for '${param_name}': ${dir_path}")
    }
}
