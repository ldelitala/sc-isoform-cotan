# Lint configuration shared by local runs and the `.github/workflows/lint.yaml` job.
#
# `object_usage_linter` is disabled: it resolves symbols against the *installed*
# packages, and CI installs lintr only (no Seurat/COTAN/dplyr), so every helper call
# and `library()` in `analysis/` is reported as "no visible global function
# definition". Run it locally in the analysis environment when you want that check:
#   lintr::lint_dir("analysis", linters = lintr::linters_with_defaults(
#     indentation_linter = NULL, return_linter = NULL, line_length_linter = lintr::line_length_linter(120)
#   ))
linters <- linters_with_defaults(
  indentation_linter = NULL,
  return_linter = NULL,
  object_usage_linter = NULL,
  line_length_linter = line_length_linter(120)
)

# `analysis/deprecated/` holds superseded code kept for provenance only (S7). It is
# unmaintained and deliberately excluded from linting. lintr resolves exclusions
# against the working directory, so give them as paths from the repository root.
exclusions <- list(
  normalizePath("analysis/deprecated/06_det_dtu.R", mustWork = FALSE),
  normalizePath("analysis/deprecated/02_ext_dtu.R", mustWork = FALSE)
)
