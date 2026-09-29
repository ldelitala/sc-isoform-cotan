include { ALIGN_SIMPLEAF } from '../modules/align'
include { require } from '../utils/helpers'

workflow PREPROCESSING {
    take:
    fastq_ch
    index_ch
    preprocessing_dir
    unfiltered_dir
    scrnaseq_params
    child_custom_config
    original_samplesheet

    main:

    require(
        [fastq_ch, index_ch, preprocessing_dir, unfiltered_dir, scrnaseq_params, original_samplesheet].every { p -> p != null },
        "Mandatory parameters are missing for the PREPROCESSING subworkflow.",
    )

    require(
        [preprocessing_dir, unfiltered_dir].every { d -> file(d).getParent()?.exists() },
        "Parent directories for 'preprocessing_dir' or 'unfiltered_dir' do not exist. Cannot write outputs.",
    )

    def srr_to_sample = [:]
    file(original_samplesheet)
        .splitCsv(header: true)
        .each { row ->
            if (row.sra && row.sample) {
                srr_to_sample[row.sra.trim()] = row.sample.trim()
            }
        }

    def raw_matrix_ch
    def raw_matrix_path = file(unfiltered_dir).resolve('raw_matrix.seurat.rds')

    if (!(raw_matrix_path.exists())) {
        def input_csv_ch = fastq_ch
            .map { srr_id, fq1, fq2 ->
                def sample_id = srr_to_sample[srr_id] ?: srr_id
                return "${sample_id},${fq1},${fq2}"
            }
            .collectFile(
                name: 'input.csv',
                storeDir: preprocessing_dir,
                newLine: true,
                seed: "sample,fastq_1,fastq_2",
                sort: true,
            )

        ALIGN_SIMPLEAF(
            input_csv_ch,
            index_ch,
            unfiltered_dir,
            preprocessing_dir,
            scrnaseq_params,
            child_custom_config,
        )

        raw_matrix_ch = ALIGN_SIMPLEAF.out.raw_seurat_matrix
    }
    else {
        raw_matrix_ch = channel.fromPath(raw_matrix_path)
    }

    emit:
    raw_matrix_ch
}

