# DTU methods

The exact definition of a differential transcript usage (DTU) candidate used for
the reported results, and the two alternative formulations that were explored and
deliberately **not** used.

## The canonical definition

Implemented as `cotanisoform::extract_dtu_candidates()`
(`src/cotanisoform/R/35_dtu.R`) and driven by `src/analysis/R/07_dtu.R`.

Idea: within one parent gene, two transcripts that are **mutually exclusive**
(negative COEX, significant) and that **switch** their relative enrichment across
cell clusters form a DTU candidate.

Two phases:

1. **Mutual exclusivity.** For every pair of transcripts sharing a `gene_id`,
   keep the pair when

   ```
   COEX(t_A, t_B) <= 0        (negative, i.e. mutually exclusive)
   p(t_A, t_B)    <= p_value_threshold   (p = 0.05)
   ```

   The `COEX <= 0` rule is hard-coded in the function; there is no config key for
   it. `p_value_threshold` is `0.05`.

2. **Cluster switch.** Using the stored cluster-level DEA matrix, compute the
   contrast `contrast(c) = DEA[t_A, c] - DEA[t_B, c]` per cluster `c`. The pair
   passes when at least one cluster has `contrast >= min_dea_contrast` **and** at
   least one cluster has `contrast <= -min_dea_contrast` — a reciprocal switch,
   not just a difference.

   `min_dea_contrast` is **0.2** for arrigoni and **0.05** for ding cortex_2: the
   values that produced the published tables. `-0.1 / 0.5` belong to an abandoned
   scratch variant that never produced a published table.

Output columns: `Gene_ID`, `Gene_Name` (when `gene_name_col` is set),
`Transcript_A`, `Transcript_B`, `COEX_Score`, `P_Value`,
`Enriched_Cell_Types_A`, `Enriched_Cell_Types_B`, `Max_Contrast_A`,
`Max_Contrast_B`. Rows are sorted by `COEX_Score` (most negative first). A CSV and
an RDS are written per output entry.

### The p-value model

All three implementations use the same COTAN significance model:

```r
p <- stats::pchisq(n_cells * coex^2, df = 1, lower.tail = FALSE)
```

where `n_cells` is the number of cells in the COTAN object. `calculate_p_value()`
populates this before DTU extraction.

## Alternatives that are **not** used

Two further implementations existed in the split `deli.*` packages and were never run
on the published datasets. Both are kept, unmaintained, under
[`src/analysis/deprecated/`](../src/analysis/deprecated/README.md). They no longer run: they
depended on the removed `deli.*` / `project.logger` helpers.

### `detect_cotan_dtu()` — `src/analysis/deprecated/06_det_dtu.R`

Global negative COEX plus the chi-squared p-value, then a further
**opposite-sign per-cluster COEX** test, and it computes a combined `DTU_Score`.
It reads row names as `GENE_TRANSCRIPT` and splits on `_` (delimiter argument).
Difference from canonical: uses per-cluster COEX rather than the DEA-contrast
switch, and reports a score instead of the two contrast columns.

### `extract_dtu_candidates()` (mutual exclusivity only) — `src/analysis/deprecated/02_ext_dtu.R`

Only pairwise mutual exclusivity (negative COEX + p-value); **no cluster step**.
Also assumes `GENE_TRANSCRIPT` row names split on `_`. It is the strict subset of
the canonical method without phase 2. Note it shares its name with the canonical
function but not its behaviour or its gene/transcript naming convention.

## Mapping to the published tables

Step `07_dtu.R` runs the canonical function once per entry in `steps.dtu.outputs`
of each config, so one COTAN object can yield several tables:

| Dataset | Clusterization | Published table | Rows |
| :--- | :--- | :--- | ---: |
| arrigoni | `Known_Cell_Types` | `results/arrigoni/dtu_candidates.csv` | 21 |
| ding cortex_2 | `local_gene_cluster` | `results/ding_cortex_2/dtu_candidates.gene_cluster.csv` | 46 |
| ding cortex_2 | `merged` | `results/ding_cortex_2/dtu_candidates.transcript_cluster.csv` | 46 |

Step `08_compare_dtu.R` intersects the two ding tables into `dtu_shared.csv` and
`dtu_exclusive_file{1,2}.csv`. The three files in `results/ding_cortex_2/` are the
**released** comparison: produced 2026-07-24 from an earlier 40/38 candidate pair, they
hold 39 shared / 3 + 4 exclusive events, and the three shared-and-exclusive tables of the
thesis appendix are built from them. Recomputing from the final 46/46 tables gives
45 shared / 1 + 1 exclusive, so step `08` does **not** reproduce the published comparison;
the released files are kept deliberately and are not refreshed.

Parity is checked by `scripts/verify_dtu_parity.R`, which reuses the stored
objects' cached p-values and DEA so COEX is never recomputed.
