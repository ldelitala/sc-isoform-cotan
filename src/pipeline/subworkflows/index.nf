include { DOWNLOAD_REFERENCE ; BUILD_INDEX ; APPLY_TRANSCRIPT_CHEAT } from '../modules/index'
include { require ; ensureDir } from '../utils/helpers'

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

    // ========================================================================
    // 1. FOL VALIDATION (P -> Q is equivalent to !P || Q)
    // ========================================================================

    // Base Requirements (Existence)
    require(
        [skip_simpleaf, transcript_level, gene_index_dir].every { p -> p != null },
        "Mandatory base parameters 'skip_simpleaf', 'transcript_level', and 'gene_index_dir' are missing.",
    )

    // Conditional Dependencies
    require(
        skip_simpleaf || [reference_dir, genome_species, genome_assembly, ensembl_release].every { p -> p != null },
        "Reference parameters missing. These are required if 'skip_simpleaf' is false. 'reference_dir', 'genome_species', 'genome_assembly', 'ensembl_release'",
    )

    require(
        !transcript_level || transcript_index_dir != null,
        "Parameter 'transcript_index_dir' is missing. Required if 'transcript_level' is true.",
    )

    // File System Integrity: Check for the 'index/' folder specifically
    require(
        !skip_simpleaf || file("${gene_index_dir}/index").exists(),
        "SimpleAF index structure not found. SimpleAF produces a directory containing 'index/', 'ref/', and metadata; " + "this pipeline expects the 'index/' subdirectory to be present within: ${gene_index_dir}",
    )

    if(transcript_level){
        ensureDir(transcript_index_dir, "transcript index directory")
    }

    // ========================================================================
    // 2. EXECUTION
    // ========================================================================

    def output_index_ch

    if (!skip_simpleaf) {
        DOWNLOAD_REFERENCE(
            reference_dir,
            genome_species,
            genome_assembly,
            ensembl_release,
        )

        output_index_ch = BUILD_INDEX(DOWNLOAD_REFERENCE.out, gene_index_dir)
    }
    else {
        log.info("\033[0;33mSkipping SimpleAF index building...\033[0m")
        output_index_ch = channel.fromPath(gene_index_dir)
            .ifEmpty { error("Pipeline error: Index not found at ${gene_index_dir}") }
    }

    if (transcript_level.toString().toBoolean()) {

        def parent_dir = file(transcript_index_dir).getParent()
        if (!parent_dir.exists()) {
            error("Invalid path: The parent directory for 'transcript_index_dir' (${parent_dir}) does not exist. Please check your configuration.")
        }

        output_index_ch = APPLY_TRANSCRIPT_CHEAT(output_index_ch, file(transcript_index_dir))
    }
  
    emit:
    output_index_ch.map { path -> path.toAbsolutePath().resolve('index').toString() }
}
