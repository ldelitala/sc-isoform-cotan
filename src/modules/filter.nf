//todo: make it so that it works when transcript=false
process QC_FILTER {
    publishDir params.filtered_dir, mode: 'copy', overwrite: true

    errorStrategy { task.exitStatus in [137, 140, 143] ? 'retry' : 'finish' }
    maxRetries 3
    memory { [100.GB * task.attempt, 2560.GB].min() }

    input:
    path raw_matrix_rds
    path mt_transcripts

    output:
    path "*_filtered.rds", emit: filtered_matrix

    script:
    """
    # Bash check: -s ensures the file exists AND size is > 0 bytes
    if [ ! -s ${raw_matrix_rds} ]; then
        echo "Process Error: Input raw matrix file is empty (0 bytes): ${raw_matrix_rds}" >&2
        exit 1
    fi

    filter_matrix.R \\
        -i ${raw_matrix_rds} \\
        -o ./ \\
        --min_features ${params.min_features} \\
        --max_features ${params.max_features} \\
        --min_counts ${params.min_counts} \\
        --max_percent_mt ${params.max_percent_mt} \\
        --mt_transcripts ${mt_transcripts}
    """
}