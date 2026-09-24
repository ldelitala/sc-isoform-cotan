# Summary

<!-- What changed and why. -->

## What was tested

<!-- Commands actually run and their outcome. -->

## Checklist

- [ ] Lint clean: `Rscript -e 'lintr::lint_dir("src/cotanisoform"); lintr::lint_dir("src/analysis")'`
- [ ] Unit tests pass: `Rscript -e 'devtools::test("src/cotanisoform")'`
- [ ] DTU parity still holds if the analysis or stored objects were touched:
      `Rscript scripts/verify_dtu_parity.R` → `3/3 cases reproduced exactly`
- [ ] No hardcoded absolute paths in tracked code
- [ ] `CHANGELOG.md` updated if the change is user-visible
- [ ] No data, `runs/`, `*.rds`, or agent files (`AGENTS.md`, `plans/`) added to git
