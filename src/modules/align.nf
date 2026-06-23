// ----------------------------------------------------------------------------
// ALIGNMENT MODULE
// Contains the isolated nf-core/scrnaseq wrapper with dynamic memory scaling
// ----------------------------------------------------------------------------

process ALIGN_SIMPLEAF {
    input:
    val input_csv
    path index_dir

    output:
    path "${params.unfiltered_dir}/raw_matrix.seurat.rds", emit: raw_seurat_matrix

    exec:
    if (!new File(input_csv.toString()).exists()) {
        throw new RuntimeException("Validation Failed: Samplesheet input CSV file does not exist: ${input_csv}")
    }
    if (!new File(index_dir.toString()).exists()) {
        throw new RuntimeException("Validation Failed: Index directory does not exist: ${index_dir}")
    }

    def run_dir = new File("${params.preprocessing_dir}")
    run_dir.mkdirs()

    // Dynamically generate nf-params.json in the run workspace
    def nf_core_params_json = new File(run_dir, "nf-params.json")
    nf_core_params_json.text = groovy.json.JsonOutput.prettyPrint(
        groovy.json.JsonOutput.toJson(
            [
                input: "input.csv",
                outdir: "results",
                skip_cellbender: true,
                simpleaf_index: index_dir.toPath().toAbsolutePath().toString(),
            ] + params.scrnaseq_params
        )
    )

    def custom_config = new File(run_dir, "custom.config")
    custom_config.text = """
    process {
        withName: 'SIMPLEAF_INDEX|SIMPLEAF_QUANT' {
            container = 'https://depot.galaxyproject.org/singularity/simpleaf:0.22.0--hd612981_0'
        }
    }
    """

    def cmd_string = "unset NXF_OPTS; unset NXF_CONFIG_FILES; export NXF_SYNTAX_PARSER=v1; nice -n 19 ionice -c 3 nextflow run nf-core/scrnaseq -r 4.1.0 -profile singularity -resume -c custom.config -params-file '${nf_core_params_json.getAbsolutePath()}' --max_cpus 72 --max_memory '2 TB'"

    def proc = ["bash", "-c", cmd_string].execute(null, run_dir)
    proc.consumeProcessOutput(System.out, System.err)
    proc.waitFor()

    if (proc.exitValue() != 0) {
        throw new RuntimeException("Child pipeline execution failed with exit code: ${proc.exitValue()}")
    }

    // Copy raw matrix to central unfiltered directory
    def src_file = new File(run_dir, "results/simpleaf/mtx_conversions/combined_raw_matrix.seurat.rds")
    def dest_file = new File("${params.unfiltered_dir}/raw_matrix.seurat.rds")
    dest_file.parentFile.mkdirs()
    java.nio.file.Files.copy(
        src_file.toPath(), 
        dest_file.toPath(), 
        java.nio.file.StandardCopyOption.REPLACE_EXISTING
    )

    def child_work_dir = new File(run_dir, "work")
    if (child_work_dir.exists()) {
        child_work_dir.deleteDir()
    }
}
