nextflow.enable.dsl = 2

process QC_FILTER {
    errorStrategy { task.exitStatus in [137,140,143] ? 'retry' : 'finish' }
    maxRetries 3
    memory { [100.GB * task.attempt, 2560.GB].min() }

    input:
    val dataset
    path raw_matrix_rds
    path mt_transcripts

    output:
    path "filtered/${dataset}_simpleaf_filtered.rds", emit: filtered_matrix

    script:
    """
    set -eo pipefail
    filter_matrix.R \\
        -i ${raw_matrix_rds} \\
        -o filtered/ \\
        -s ${dataset}_simpleaf \\
        --min_features ${params.min_features} \\
        --max_features ${params.max_features} \\
        --min_counts ${params.min_counts} \\
        --max_percent_mt ${params.max_percent_mt} \\
        --mt_transcripts ${mt_transcripts}
    """
}
