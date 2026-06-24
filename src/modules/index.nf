nextflow.enable.dsl = 2

// --- HELPER FUNCTIONS ---
def getFastaUrl(sp, asm, rel) { "http://ftp.ensembl.org/pub/release-${rel}/fasta/${sp.toLowerCase()}/dna/${sp.capitalize()}.${asm}.dna.primary_assembly.fa.gz" }
def getGtfUrl(sp, asm, rel) { "http://ftp.ensembl.org/pub/release-${rel}/gtf/${sp.toLowerCase()}/${sp.capitalize()}.${asm}.${rel}.gtf.gz" }

// --- PROCESSES ---

process DOWNLOAD_REFERENCE {
    storeDir reference_dir

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
    set -eo pipefail
    
    # Download to temporary names first
    if wget -q --spider "${fasta_url}"; then
        wget -q -O temp_genome.fa.gz "${fasta_url}"
    else
        wget -q -O temp_genome.fa.gz "${fasta_url.replace('primary_assembly', 'toplevel')}"
    fi
    wget -q -O temp_anno.gtf.gz "${gtf_url}"

    # Only rename to final outputs if downloads finish perfectly
    mv temp_genome.fa.gz genome.fa.gz
    mv temp_anno.gtf.gz annotation.gtf.gz
    """
}

process BUILD_INDEX {
    container 'https://depot.galaxyproject.org/singularity/simpleaf:0.22.0--hd612981_0'
    storeDir { file(gene_index_dir).getParent() }

    input:
    tuple path(fasta_file), path(gtf_file)
    val gene_index_dir

    output:
    path "${file(gene_index_dir).getName()}", emit: index_dir

    script:
    def folder = file(gene_index_dir).getName()
    """
    export ALEVIN_FRY_HOME=\$PWD
    simpleaf set-paths
    
    # Build to a temporary folder
    simpleaf index -f ${fasta_file} -g ${gtf_file} -o temp_index -t ${task.cpus}

    # Only create the final folder if the build didn't crash
    mv temp_index ${folder}
    """
}

process APPLY_TRANSCRIPT_CHEAT {
    publishDir transcript_index_dir, mode: 'copy', overwrite: true

    input:
    path gene_index_dir
    val transcript_index_dir

    output:
    path "modified_index", emit: transcript_index

    script:
    """
    cp -rL ${gene_index_dir} modified_index
    cd modified_index/index
    
    # 1. Extract MT transcripts by cross-referencing gene_id_to_name.tsv with t2g_3col.tsv
    awk -F'\\t' 'NR==FNR {if (\$2 ~ /^[Mm][Tt][-|_]/) mt[\$1]=1; next} {if (\$2 in mt) print \$1}' gene_id_to_name.tsv t2g_3col.tsv > mt_transcripts.txt
    
    # Apply Transcript Cheat
    awk -F'\t' 'BEGIN {OFS="\t"} {print \$1, \$1, \$3}' t2g_3col.tsv > tmp.tsv
    mv tmp.tsv t2g_3col.tsv
    
    # Cleanup
    rm -f gene_id_to_name.tsv
    """
}