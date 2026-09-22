---
name: Bug report
about: Something produced a wrong result or crashed
title: ""
labels: bug
assignees: ""
---

## What happened

<!-- The observed behaviour, with the command that produced it. -->

## What was expected

<!-- The result you expected instead. -->

## Reproduction

```bash
# the exact command(s), e.g.
# Rscript analysis/run_all.R --config analysis/config/arrigoni.yaml --from 07 --to 08
```

## Environment

```
# conda env export -n cotanisoform-analysis | head -40
# R version, COTAN version (utils::packageVersion("COTAN")), nextflow -version
```

## Dataset / config used

<!-- e.g. arrigoni transcript level, analysis/config/arrigoni.yaml -->

## Anything else

<!-- Logs, stack traces, screenshots. -->
