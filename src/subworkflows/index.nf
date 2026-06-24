include { DOWNLOAD_REFERENCE ; BUILD_INDEX ; APPLY_TRANSCRIPT_CHEAT } from '../modules/index'

workflow PREPARE_INDEX {
    main:
        def output_index_ch

        if (!params.skip_simpleaf) {
            DOWNLOAD_REFERENCE(
                params.reference_dir,
                params.genome_species,
                params.genome_assembly,
                params.ensembl_release,
            )
            log.info("\033[0;32mStarting SimpleAF index building...\033[0m")
            output_index_ch = BUILD_INDEX(DOWNLOAD_REFERENCE.out, params.gene_index_dir)
        } else {
            log.info("\033[0;33mSkipping SimpleAF index building...\033[0m")
            output_index_ch = channel.fromPath(params.gene_index_dir)
                .ifEmpty { error("Pipeline error: Index not found at ${params.gene_index_dir}") }
        }

        if (params.transcript_level.toString().toBoolean()) {
            output_index_ch = APPLY_TRANSCRIPT_CHEAT(output_index_ch, file(params.transcript_index_dir))
        }

        output_index_ch = output_index_ch.map { path -> path.toAbsolutePath().resolve('index').toString() }

    emit:
        index_dir = output_index_ch
}