# Deprecated DTU implementations

Superseded code, kept for provenance only. **Nothing in the repository sources these
files**, and `src/analysis/run_all.R` never sees them (it globs `src/analysis/R/` only,
non-recursively).

| File | Function | Original home |
| :--- | :--- | :--- |
| `06_det_dtu.R` | `detect_cotan_dtu()` | `src/libs/deli.dtu/R/06_det_dtu.R` |
| `02_ext_dtu.R` | `extract_dtu_candidates()` | `src/libs/deli.dtu/R/02_ext_dtu.R` |

Both were superseded by the canonical `cotanisoform::extract_dtu_candidates()` (COEX +
p-value, then a reciprocal DEA-contrast switch across clusters), which is what produced
every published table. Their differences and semantics are recorded in
[`docs/dtu_methods.md`](../../../docs/dtu_methods.md).

## They do not run as-is

- Both call `log_header()` / `log_info()` / `log_stat()` / `log_warn()` / `log_error()`
  from the removed `deli.dtu` / `project.logger` layer.
- They assume COTAN row names of the form `GENE_TRANSCRIPT`, split on `_`.
- `06_det_dtu.R` also imports `deli.cotan.core` / `cotan.deli.vis` symbols.

They are kept as a readable record of the two abandoned formulations, not as runnable
code. Linting is disabled for this directory in [`.lintr.R`](../../../.lintr.R).

## `detect_cotan_dtu()` — `06_det_dtu.R`

Global negative COEX plus the chi-squared p-value, then a further
**opposite-sign per-cluster COEX** test, and it computes a combined `DTU_Score`.
It reads row names as `GENE_TRANSCRIPT` and splits on `_` (delimiter argument).
Difference from canonical: uses per-cluster COEX rather than the DEA-contrast
switch, and reports a score instead of the two contrast columns.

## `extract_dtu_candidates()` (mutual exclusivity only) — `02_ext_dtu.R`

Only pairwise mutual exclusivity (negative COEX + p-value); **no cluster step**.
Also assumes `GENE_TRANSCRIPT` row names split on `_`. It is the strict subset of
the canonical method without phase 2. Note it shares its name with the canonical
function but not its behaviour or its gene/transcript naming convention.
