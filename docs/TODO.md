# TODO / backlog

Open work items for this repository. Not authoritative documentation.

- **Per-cluster isoform-proportion plots for the headline DTU candidates.** The
  thesis reports TPM1 (human) and Meg3, Malat1 (mouse) as its top hits but has no
  figure showing their per-cluster isoform proportions. The data needed is in the
  COTAN objects on `athena`, not in `results/*/tables/dtu_candidates*.csv`. Planned
  route: a `plot_isoform_proportions()` helper in `src/cotanisoform`, run once per
  candidate, writing a figure next to `results/<dataset>/plots/`.
