// utils/init.nf

def printPipelineInfo(params, launchDir, projectDir, workDir, profile) {
    def c_reset = "\033[0m"
    def c_green = "\033[0;32m"
    
    log.info(
        """
    ${c_green}========================================================================${c_reset}
    ${c_green}P I P E L I N E   E X E C U T I O N   I N F O R M A T I O N${c_reset}
    ${c_green}========================================================================${c_reset}
    * Dataset Directory   : ${params.dataset_dir ?: 'Not provided'}
    * Pipeline Step       : ${params.step}
    * SRA Run IDs         : ${params.srr_ids ?: 'Not provided'}
    * Genome Assembly     : ${params.genome_assembly ?: 'Not provided'}
    * Genome Species      : ${params.genome_species ?: 'None'}
    * SimpleAF Index Path : ${params.index_dir ?: 'Not provided'}
    * Transcript Level    : ${params.transcript_level}
    
    [Execution Context]
    * Launch Directory    : ${launchDir}
    * Project Directory   : ${projectDir}
    * Work Directory      : ${workDir}
    * Profile             : ${profile}
    ${c_green}========================================================================${c_reset}
    """
    )
}

def validateParameters(params) {
    if (params.step in ['all', 'download']) {
        validateDirectoryWritable(params.dataset_dir, 'dataset_dir')
    }
    if (params.step in ['all', 'index']) {
        validateDirectoryWritable(params.reference_dir, 'reference_dir')
        if (!params.skip_simpleaf) validateDirectoryWritable(params.index_dir, 'index_dir')
    }
    if (params.step in ['all', 'align']) {
        validateDirectoryWritable(params.preprocessing_dir, 'preprocessing_dir')
        validateDirectoryWritable(params.unfiltered_dir, 'unfiltered_dir')
        if (params.skip_simpleaf) validatePiscemIndex(params.index_dir)
    }
    if (params.step in ['all', 'filter']) {
        validateDirectoryWritable(params.filtered_dir, 'filtered_dir')
    }
}

// ----------------------------------------------------------------------------
// INTERNAL VALIDATION HELPERS
// ----------------------------------------------------------------------------
def validatePiscemIndex(index_dir) {
    if (!index_dir) error("Validation Error: 'index_dir' is required but not configured.")
    def index_path = file(index_dir)
    if (!index_path.exists()) error("Validation Error: Specified index path does not exist: ${index_dir}")
    
    def nested_index = file("${index_dir}/index")
    def has_t2g = file("${index_path}/t2g_3col.tsv").exists() || file("${nested_index}/t2g_3col.tsv").exists()
    def has_piscem = file("${index_path}/piscem_idx.ssi").exists() || file("${nested_index}/piscem_idx.ssi").exists()
    def has_salmon = file("${index_path}/ref_core.hash").exists() || file("${nested_index}/ref_core.hash").exists()

    if (!has_t2g || !(has_piscem || has_salmon)) {
        error("Validation Error: Malformed simpleaf index at ${index_dir}. Missing required index files.")
    }
}

def validateDirectoryWritable(dir_path, param_name) {
    if (!dir_path) error("Validation Error: Parameter '${param_name}' is empty.")
    def target = file(dir_path)

    def check_dir = target.exists() ? target : target.getParent()
    if (check_dir != null && !check_dir.exists()) check_dir = check_dir.getParent()

    if (check_dir == null || !check_dir.exists() || !check_dir.toFile().canWrite()) {
        error("Validation Error: Target path or its parent is not writable for '${param_name}': ${dir_path}")
    }
}