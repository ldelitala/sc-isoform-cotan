// ----------------------------------------------------------------------------
// ALIGNMENT MODULE
// Contains the isolated nf-core/scrnaseq wrapper with dynamic memory scaling
// ----------------------------------------------------------------------------

process ALIGN_SIMPLEAF {
    publishDir path: { "runs/${dataset}_simpleaf" }, mode: 'copy'
    errorStrategy { task.exitStatus in [137, 140, 143] ? 'retry' : 'finish' }
    maxRetries 2
    memory { [2048.GB * task.attempt, 2560.GB].min() }

    input:
    val dataset
    path input_csv
    path nf_core_params_json

    output:
    path "results/simpleaf/mtx_conversions/combined_raw_matrix.seurat.rds", emit: raw_seurat_matrix

    script:
    """
    set -eo pipefail
    
    # Unset any inherited config files from the parent pipeline
    unset NXF_OPTS
    unset NXF_CONFIG_FILES

    # Force v1 syntax parser for compatibility with nf-core/scrnaseq 4.1.0 under Nextflow 26+
    export NXF_SYNTAX_PARSER=v1

    # Safely isolate the child's execution environment
    export NXF_WORK="\$(pwd)/nxf_work"
    
    # 1. Clone the pipeline into a temporary folder
    git clone --depth 1 -b 4.1.0 https://github.com/nf-core/scrnaseq.git temp_clone
    
    # 2. Copy the pipeline directly into the root of our working directory
    cp -r temp_clone/. .
    rm -rf temp_clone

    # Write custom config to override simpleaf container to version matching the newer piscem index
    cat << 'EOF' > custom.config
    process {
        withName: 'SIMPLEAF_INDEX|SIMPLEAF_QUANT' {
            container = 'https://depot.galaxyproject.org/singularity/simpleaf:0.22.0--h2a3260d_0'
        }
    }
    EOF
    
    # 3. Execute the pipeline from the CURRENT directory
    # This guarantees all relative paths (like conf/test_multiome.config) resolve perfectly
    nextflow run . \\
        -profile singularity \\
        -resume \\
        -c custom.config \\
        -params-file ${nf_core_params_json} \\
        --max_cpus "${task.cpus}" \\
        --max_memory "${task.memory}"

    # Cleanup the nested work directory to reclaim disk space
    rm -rf nxf_work/
    """
}
