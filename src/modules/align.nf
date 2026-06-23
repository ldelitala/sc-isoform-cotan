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
    def run_dir = new File("${params.preprocessing_dir}")
    run_dir.mkdirs()

    // Execute separate steps via modular helper functions
    validateAlignInputs(input_csv, index_dir)
    
    def params_json_path = writeParamsJson(run_dir, index_dir, params.scrnaseq_params)
    
    writeCustomConfig(run_dir)
    
    runChildNextflow(run_dir, params_json_path)
    
    stageOutputMatrix(run_dir, "${params.unfiltered_dir}")
    
    cleanChildWorkDir(run_dir)
}

// ----------------------------------------------------------------------------
// HELPER FUNCTIONS (Process-specific actions)
// ----------------------------------------------------------------------------

// 1. Validates inputs before running child pipeline
def validateAlignInputs(input_csv, index_dir) {
    if (!new File(input_csv.toString()).exists()) {
        throw new RuntimeException("Validation Failed: Samplesheet input CSV file does not exist: ${input_csv}")
    }
    if (!new File(index_dir.toString()).exists()) {
        throw new RuntimeException("Validation Failed: Index directory does not exist: ${index_dir}")
    }
}

// 2. Generates nf-params.json configuration file
def writeParamsJson(run_dir, index_dir, scrnaseq_params) {
    def jsonFile = new File(run_dir, "nf-params.json")
    jsonFile.text = groovy.json.JsonOutput.prettyPrint(
        groovy.json.JsonOutput.toJson(
            [
                input: "input.csv",
                outdir: "results",
                skip_cellbender: true,
                simpleaf_index: index_dir.toPath().toAbsolutePath().toString(),
            ] + scrnaseq_params
        )
    )
    return jsonFile.getAbsolutePath()
}

// 3. Generates custom.config for singularity container overrides
def writeCustomConfig(run_dir) {
    def custom_config = new File(run_dir, "custom.config")
    custom_config.text = """
    process {
        withName: 'SIMPLEAF_INDEX|SIMPLEAF_QUANT' {
            container = 'https://depot.galaxyproject.org/singularity/simpleaf:0.22.0--hd612981_0'
        }
    }
    """
    return custom_config.getAbsolutePath()
}

// 4. Runs child nextflow execution synchronously
def runChildNextflow(run_dir, params_json_path) {
    def cmd_string = "unset NXF_OPTS; unset NXF_CONFIG_FILES; export NXF_SYNTAX_PARSER=v1; nice -n 19 ionice -c 3 nextflow run nf-core/scrnaseq -r 4.1.0 -profile singularity -resume -c custom.config -params-file '${params_json_path}' --max_cpus 72 --max_memory '2 TB'"
    def proc = ["bash", "-c", cmd_string].execute(null, run_dir)
    proc.consumeProcessOutput(System.out, System.err)
    proc.waitFor()
    if (proc.exitValue() != 0) {
        throw new RuntimeException("Child pipeline execution failed with exit code: ${proc.exitValue()}")
    }
}

// 5. Copies the output Seurat RDS matrix to central unfiltered directory
def stageOutputMatrix(run_dir, unfiltered_dir) {
    def src_file = new File(run_dir, "results/simpleaf/mtx_conversions/combined_raw_matrix.seurat.rds")
    def dest_file = new File(unfiltered_dir, "raw_matrix.seurat.rds")
    dest_file.parentFile.mkdirs()
    java.nio.file.Files.copy(
        src_file.toPath(), 
        dest_file.toPath(), 
        java.nio.file.StandardCopyOption.REPLACE_EXISTING
    )
}

// 6. Cleans up intermediate work directory inside runs
def cleanChildWorkDir(run_dir) {
    def child_work_dir = new File(run_dir, "work")
    if (child_work_dir.exists()) {
        child_work_dir.deleteDir()
    }
}
