nextflow.enable.dsl = 2

/**
 * DOWNLOAD_REFERENCE
 * Downloads FASTA and GTF files from Ensembl.
 * Uses 'storeDir' to cache raw reference files permanently.
 */
process DOWNLOAD_REFERENCE {
    storeDir { "${reference_dir}/" }

    input:
    val reference_dir
    val reference_urls
    val genome_species
    val genome_assembly
    val ensembl_release

    output:
    tuple path("*.fa.gz"), path("*.gtf.gz")

    script:
    genome_assembly ?: error("Missing required parameter: genome_assembly")
    def urls = reference_urls ? reference_urls[genome_assembly] : null
    if (!urls) {
        if (genome_species && genome_assembly) {
            def species = genome_species.toLowerCase().trim()
            def assembly = genome_assembly.trim()
            def release = ensembl_release
            def species_cap = species.substring(0, 1).toUpperCase() + species.substring(1)
            urls = [fasta: "http://ftp.ensembl.org/pub/release-${release}/fasta/${species}/dna/${species_cap}.${assembly}.dna.primary_assembly.fa.gz", gtf: "http://ftp.ensembl.org/pub/release-${release}/gtf/${species}/${species_cap}.${assembly}.${release}.gtf.gz"]
        }
        else {
            error("No reference URLs configured for genome: ${genome_assembly}. Use '--genome_species <species>' and '--genome_assembly <assembly>' to resolve dynamically.")
        }
    }
    def fasta_url = urls.fasta
    def gtf_url = urls.gtf
    def fasta_file = fasta_url.substring(fasta_url.lastIndexOf('/') + 1)
    def gtf_file = gtf_url.substring(gtf_url.lastIndexOf('/') + 1)

    """
    set -eo pipefail
    
    if wget -q --spider "${fasta_url}"; then
        wget -q -O "${fasta_file}" "${fasta_url}"
    else
        fallback_url=\$(echo "${fasta_url}" | sed 's/primary_assembly/toplevel/')
        wget -q -O "${fasta_file}" "\${fallback_url}"
    fi

    wget -q -O "${gtf_file}" "${gtf_url}"
    """
}

/**
 * BUILD_INDEX
 * Generates a simpleaf index from FASTA/GTF files.
 * Uses dynamic storeDir to place the index folder exactly at the provided path.
 */
process BUILD_INDEX {
    container 'https://depot.galaxyproject.org/singularity/simpleaf:0.22.0--hd612981_0'
    storeDir { file(gene_index_dir).getParent() }

    input:
    tuple path(fasta_file), path(gtf_file)
    val gene_index_dir

    output:
    path(file(gene_index_dir).getName()), emit: gene_index_dir

    script:
    gene_index_dir ?: error("Missing required parameter: gene_index_dir")
    def folder_name = file(gene_index_dir).getName()
    """
    set -eo pipefail
    export ALEVIN_FRY_HOME="\$PWD"
    simpleaf set-paths
    simpleaf index \\
        -f "${fasta_file}" \\
        -g "${gtf_file}" \\
        -o "${folder_name}" \\
        -t ${task.cpus}
    """
}

/**
 * APPLY_TRANSCRIPT_CHEAT
 * Creates an idempotent, modified transcript index by mapping transcripts to themselves.
 * Outputs a folder 'transcript_index' side-by-side with the original input index.
 */
process APPLY_TRANSCRIPT_CHEAT {
    storeDir { store_dir }

    input:
    path index_dir
    val store_dir

    output:
    path "transcript_index", emit: transcript_index_dir

    script:
    """
    set -eo pipefail
    
    # 1. Create workspace and copy original index contents
    mkdir -p transcript_index
    cp -rL "${index_dir}/"* transcript_index/
    
    # 2. Extract mitochondrial transcript IDs before modifying/deleting mapping files
    MT_OUT="transcript_index/mt_transcripts.txt"
    touch "\${MT_OUT}"

    T2G_FILE=\$(find transcript_index -name "t2g_3col.tsv" | head -n 1)
    G2N_FILE=\$(find transcript_index -name "gene_id_to_name.tsv" | head -n 1)

    if [ -f "\${T2G_FILE}" ]; then
        awk -F'\t' '{if (NF >= 3 && (\$3 ~ /^[Mm][Tt][-|_]/)) print \$1}' "\${T2G_FILE}" >> "\${MT_OUT}"
    fi

    if [ -f "\${G2N_FILE}" ] && [ -f "\${T2G_FILE}" ]; then
        awk -F'\t' '{if (\$2 ~ /^[Mm][Tt][-|_]/) print \$1}' "\${G2N_FILE}" > mt_genes.tmp
        awk -F'\t' 'NR==FNR {mt[\$1]=1; next} {if (\$2 in mt) print \$1}' mt_genes.tmp "\${T2G_FILE}" >> "\${MT_OUT}"
        rm -f mt_genes.tmp
    fi

    sort -u "\${MT_OUT}" -o "\${MT_OUT}"
    echo "Extracted \$(wc -l < "\${MT_OUT}") mitochondrial transcripts."

    # 3. Idempotently modify t2g_3col.tsv
    if [ -f "\${T2G_FILE}" ]; then
        awk -F'\t' 'BEGIN {OFS="\t"} {if (NF>=3) print \$1, \$1, \$3; else print \$1, \$1}' "\${T2G_FILE}" > "\${T2G_FILE}.tmp"
        mv -f "\${T2G_FILE}.tmp" "\${T2G_FILE}"
    fi

    # 4. Clean up non-essential mapping files
    find transcript_index -name "gene_id_to_name.tsv" -delete
    """
}