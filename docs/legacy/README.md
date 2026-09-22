# Legacy design notes

**Historical. Do not trust these against the current code.**

These documents were written earlier in the project, when the repository layout
was flat (`bin/`, `modules/`, `nextflow.config` at the root) and the pipeline had
steps `all`/`filter` and parameters (`srr_ids`, `index_dir`, `genome`) that no
longer exist. They are kept for the design record only.

For the current picture see [`../README.md`](../README.md),
[`../athena_layout.md`](../athena_layout.md) and the code.

| File | Why it is legacy |
| :--- | :--- |
| `1_configuration_parameters.md` | old parameter names; steps `all`/`filter` |
| `2_cluster_resource_management.md` | resource math and `beforeScript` do not match `nextflow.config` |
| `6_downstream_analysis.md` | aspirational; the SCALPEL path was never implemented |
| `LINEE GUIDA.md` | proposed Nextflow COTAN stages; not implemented in the pipeline |
| `pipeline_architecture_workflows.md` | steps `all`/`filter`, container `0.22.0` |
