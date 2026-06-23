nextflow.enable.dsl = 2

process QC_FILTER {
    errorStrategy { task.exitStatus in [137,140,143] ? 'retry' : 'finish' }
    maxRetries 3
    memory { [100.GB * task.attempt, 2560.GB].min() }

    input:
    path raw_matrix_rds
    path mt_transcripts

    output:
    path "${params.filtered_dir}/*_filtered.rds", emit: filtered_matrix

    script:
    if (!file(raw_matrix_rds).exists()) {
        error "Process Error: Input raw matrix file is missing: ${raw_matrix_rds}"
    }
    if (file(raw_matrix_rds).size() == 0) {
        error "Process Error: Input raw matrix file is empty (0 bytes): ${raw_matrix_rds}"
    }
    """
    set -eo pipefail
    filter_matrix.R \\
        -i ${raw_matrix_rds} \\
        -o ${params.filtered_dir}/ \\
        --min_features ${params.min_features} \\
        --max_features ${params.max_features} \\
        --min_counts ${params.min_counts} \\
        --max_percent_mt ${params.max_percent_mt} \\
        --mt_transcripts ${mt_transcripts}
    """
}
