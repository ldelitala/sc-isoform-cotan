include { DOWNLOAD_REFERENCE ; BUILD_INDEX ; APPLY_TRANSCRIPT_CHEAT } from '../modules/index'
include { ERR_MISS ; sendWebhook } from '../utils/helpers'

/*
 * SUBWORKFLOW: PREPARE_INDEX
 * * Description:
 * Orchestrates the downloading of reference genome and annotation files, and the building of a SimpleAF index.
 * Uses the reference dir and gene index dir as cache with storeDir to avoid re-downloading files.
 * If skip_simpleaf is true, it skips the index building step and uses the provided gene index dir.
 * If transcript_level is true, it applies a transcript-level cheat to the index. 
 */
workflow PREPARE_INDEX {
    take:
    skip_simpleaf
    transcript_level
    reference_dir
    gene_index_dir
    transcript_index_dir
    genome_species
    genome_assembly
    ensembl_release

    main:

    // fast check 
    skip_simpleaf == null ?: ERR_MISS('skip_simpleaf')
    transcript_level == null ?: ERR_MISS('transcript_level')
    reference_dir ?: ERR_MISS('reference_dir')
    gene_index_dir ?: ERR_MISS('gene_index_dir')

    // Only require transcript_index_dir if we intend to perform the cheat
    if (transcript_level.toString().toBoolean()) {
        transcript_index_dir ?: ERR_MISS('transcript_index_dir')
    }

    // These parameters are only strictly required if we are NOT skipping simpleaf
    if (!skip_simpleaf.toString().toBoolean()) {
        genome_species ?: ERR_MISS('genome_species')
        genome_assembly ?: ERR_MISS('genome_assembly')
        ensembl_release ?: ERR_MISS('ensembl_release')
    }


    def output_index_ch

    if (!skip_simpleaf) {
        DOWNLOAD_REFERENCE(
            reference_dir,
            genome_species,
            genome_assembly,
            ensembl_release,
        )

        log.info("\033[0;32mStarting SimpleAF index building...\033[0m")

        output_index_ch = BUILD_INDEX(DOWNLOAD_REFERENCE.out, gene_index_dir)
        output_index_ch.tap { webhook_build_ch }
        webhook_build_ch.subscribe { sendWebhook("Indexing finished.", 'info') }
    }
    else {
        log.info("\033[0;33mSkipping SimpleAF index building...\033[0m")
        output_index_ch = channel.fromPath(gene_index_dir)
            .ifEmpty { error("Pipeline error: Index not found at ${gene_index_dir}") }
    }

    if (transcript_level.toString().toBoolean()) {
        output_index_ch = APPLY_TRANSCRIPT_CHEAT(output_index_ch, file(transcript_index_dir))
        output_index_ch.tap { webhook_cheat_ch }
        webhook_cheat_ch.subscribe { sendWebhook("Transcript Cheat applied.", 'info') }
    }

    emit:
    output_index_ch.map { path -> path.toAbsolutePath().resolve('index').toString() }
}
