// utils/init.nf

// ----------------------------------------------------------------------------
// LOGGING HELPER FUNCTIONS
// ----------------------------------------------------------------------------
def fmtVal(val) {
    def c_reset  = "\033[0m"
    def c_yellow = "\033[0;33m"
    def c_dim    = "\033[2m"
    return val ? "${c_yellow}${val}${c_reset}" : "${c_dim}Not specified${c_reset}"
}

def fmtBool(val) {
    def c_reset  = "\033[0m"
    def c_green  = "\033[0;32m"
    def c_yellow = "\033[0;33m"
    return val ? "${c_green}Yes${c_reset}" : "${c_yellow}No${c_reset}"
}

// ----------------------------------------------------------------------------
// MAIN LOGGING FUNCTION
// ----------------------------------------------------------------------------
def printPipelineInfo(params, launchDir, projectDir, workDir, profile) {
    
    // Extended ANSI Color Palette
    def c_reset  = "\033[0m"
    def c_bold   = "\033[1m"
    def c_dim    = "\033[2m"
    def c_green  = "\033[0;32m"
    def c_yellow = "\033[0;33m"
    def c_blue   = "\033[0;34m"
    def c_cyan   = "\033[0;36m"
    
    log.info(
        """
    ${c_blue}${c_bold}================================================================================${c_reset}
    ${c_green}${c_bold}                s c - I s o f o r m   P i p e l i n e                           ${c_reset}
    ${c_blue}${c_bold}================================================================================${c_reset}

    ${c_cyan}${c_bold}▶ RUN CONFIGURATION${c_reset}
      ${c_bold}Pipeline Step        ${c_reset}: ${fmtVal(params.step)}
      ${c_bold}Active Profile       ${c_reset}: ${fmtVal(profile ?: 'standard')}
      ${c_bold}SRA Run IDs          ${c_reset}: ${params.srr_ids ? c_yellow + params.srr_ids + c_reset : c_dim + 'None (Using local data)' + c_reset}

    ${c_cyan}${c_bold}▶ REFERENCE & INDEXING${c_reset}
      ${c_bold}Genome Assembly      ${c_reset}: ${fmtVal(params.genome_assembly)}
      ${c_bold}Genome Species       ${c_reset}: ${fmtVal(params.genome_species)}
      ${c_bold}Transcript Level     ${c_reset}: ${fmtBool(params.transcript_level)}
      ${c_bold}Skip SimpleAF Index  ${c_reset}: ${fmtBool(params.skip_simpleaf)}

    ${c_cyan}${c_bold}▶ ALIGNMENT PARAMETERS${c_reset}
      ${c_bold}Protocol             ${c_reset}: ${fmtVal(params.scrnaseq_params?.protocol)}
      ${c_bold}UMI Resolution       ${c_reset}: ${fmtVal(params.scrnaseq_params?.simpleaf_umi_resolution)}
      ${c_bold}Custom Geometry      ${c_reset}: ${fmtVal(params.scrnaseq_params?.custom_geometry)}

    ${c_cyan}${c_bold}▶ QC THRESHOLDS${c_reset}
      ${c_bold}Min / Max Features   ${c_reset}: ${c_yellow}${params.min_features}${c_reset} / ${c_yellow}${params.max_features}${c_reset}
      ${c_bold}Minimum Counts       ${c_reset}: ${c_yellow}${params.min_counts}${c_reset}
      ${c_bold}Max Mito (%)         ${c_reset}: ${c_yellow}${params.max_percent_mt}%${c_reset}

    ${c_cyan}${c_bold}▶ FILE SYSTEM${c_reset}
      ${c_bold}Dataset Dir          ${c_reset}: ${c_dim}${params.dataset_dir}${c_reset}
      ${c_bold}Reference Dir        ${c_reset}: ${c_dim}${params.reference_dir}${c_reset}
      ${c_bold}Gene Index Dir       ${c_reset}: ${c_dim}${params.gene_index_dir}${c_reset}
      ${c_bold}Work Dir             ${c_reset}: ${c_dim}${workDir}${c_reset}

    ${c_cyan}${c_bold}▶ SYSTEM & ALERTS${c_reset}
      ${c_bold}Launch Dir           ${c_reset}: ${c_dim}${launchDir}${c_reset}
      ${c_bold}Discord/Slack Alerts ${c_reset}: ${params.webhook_url ? c_green + 'Enabled' + c_reset : c_dim + 'Disabled' + c_reset}
    ${c_blue}${c_bold}================================================================================${c_reset}
    """
    )
}
