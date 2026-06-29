nextflow.enable.dsl = 2

// --- HELPER FUNCTIONS ---
def getFastaUrl(sp, asm, rel) { "http://ftp.ensembl.org/pub/release-${rel}/fasta/${sp.toLowerCase()}/dna/${sp.capitalize()}.${asm}.dna.primary_assembly.fa.gz" }
def getGtfUrl(sp, asm, rel) { "http://ftp.ensembl.org/pub/release-${rel}/gtf/${sp.toLowerCase()}/${sp.capitalize()}.${asm}.${rel}.gtf.gz" }

// --- PROCESSES ---

process DOWNLOAD_REFERENCE {
    storeDir { reference_dir }

    input:
    val reference_dir
    val genome_species
    val genome_assembly
    val ensembl_release

    output:
    tuple path("*.fa.gz"), path("*.gtf.gz")

    script:
    def fasta_url = getFastaUrl(genome_species, genome_assembly, ensembl_release)
    def gtf_url = getGtfUrl(genome_species, genome_assembly, ensembl_release)
    """
    ingest/download_ref.sh ${fasta_url} ${gtf_url}
    """
}

process BUILD_INDEX {
    container 'https://depot.galaxyproject.org/singularity/simpleaf:0.24.0--hd612981_1'
    storeDir { file(gene_index_dir).getParent() }

    input:
    tuple path(fasta_file), path(gtf_file)
    val gene_index_dir

    output:
    path "${file(gene_index_dir).getName()}", emit: index_dir

    script:
    """
    ingest/build_index.sh ${fasta_file} ${gtf_file} ${task.cpus} ${file(gene_index_dir).getName()}
    """
}

process APPLY_TRANSCRIPT_CHEAT {
    publishDir { file(transcript_index_dir).getParent() }, mode: 'copy', overwrite: true

    input:
    path gene_index_dir
    val transcript_index_dir

    output:
    path "transcript_index", emit: transcript_index

    script:
    """
    ingest/apply_cheat.sh ${gene_index_dir} transcript_index
    """
}