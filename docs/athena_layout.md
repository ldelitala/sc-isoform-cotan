# athena layout and access

How to reach the university machine, where everything lives, and what is safe to
delete. Sizes measured 2026-09-22.

## Access

`athena` is reached over a **reverse SSH tunnel held open from carl** (the Linux
PC with the unipi VPN). From the Mac, `ssh athena` maps to `127.0.0.1:2222`. If a
connection fails, the tunnel is down — restart it on carl (tmux session
`athena-tunnel`):

```bash
ssh -N -R 2222:131.114.50.65:22 \
  -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -o TCPKeepAlive=yes \
  deli@100.67.91.12
```

Health check: `ssh athena hostname` must print `Athena`.

### Tunnel troubleshooting

Three different symptoms, three different fixes:

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| `remote port forwarding failed for listen port 2222` (on carl) | A stale Mac-side `sshd-session` still holds the forwarded port | On the Mac: `lsof -nP -iTCP:2222 -sTCP:LISTEN` → `kill <pid>`, then relaunch the tunnel |
| `Connection timed out during banner exchange` (from the Mac) | Socket opens but the relay is wedged — carl is not reaching athena | Prove the VPN **from carl**: `ssh lorenzo_delitala@131.114.50.65 hostname` |
| `Connection reset by peer` | No tunnel at all | Relaunch the tmux tunnel on carl |

The Mac has no `timeout`/`gtimeout`; use `ssh -o ConnectTimeout=N`.

athena has **no `sudo`** and `/data` is root-owned, so scratch checkouts go under
`$HOME` (only ~30 GB free there — keep code, not data).

## Directory layout

The tree is split by **provenance**: downloaded inputs, built references, computed
work, published results. Root: `/data/lorenzo_delitala` (~450 GB total).

| Path | Size | Holds | Regenerable? |
| :--- | ---: | :--- | :--- |
| `src/` | 3.6 MB | the git working tree (this repo: code + configs) | no |
| `results/` | 158 MB | curated published outputs (tracked) | no |
| `docs/`, `scripts/`, `envs/` | <1 MB | tracked code + docs | no |
| `inputs/` | ~250 GB | downloaded external data (see below) | re-download |
| `built/` | ~18 GB | indices made from `inputs/reference` | rebuild (hours) |
| `work/` | ~158 GB | computed pipeline + analysis output (see below) | re-run |
| `COTAN/` | 138 MB | COTAN source clone (pinned commit) | re-clonable, but keep |
| `.conda/` | 19 GB | the `cotanisoform-*` conda envs | recreate with `conda env create` — keep |
| `.cache/` | 3.1 GB | `ncbi/refseq` 635 MB, `singularity/` 2.4 GB | — |
| `scratch/` | small | obsolete leftovers kept this session | yes |

### `inputs/` — downloaded, not computed

| Path | Size | Contents |
| :--- | ---: | :--- |
| `inputs/fastqs/<dataset>/` | 248 GB | per-dataset FASTQs (re-downloadable from SRA) |
| `inputs/geo_metadata/<dataset>/` | 345 MB | GEO barcode files for QC and cell types |
| `inputs/reference/{GRCh38,GRCm39}/` | 1.7 GB | Ensembl 102 `genome.fa.gz` + `annotation.gtf.gz` |

### `built/` — made from `inputs/reference`

| Path | Size | Made by |
| :--- | ---: | :--- |
| `built/<asm>/gene_index/` | 8.8 GB | `simpleaf index` (pipeline `2.2`, hours); holds the real `t2g_3col.tsv` + `gene_id_to_name.tsv` used by step 00 |
| `built/<asm>/transcript_index/` | 8.8 GB | `2.3_index_apply_cheat.sh` — copy of `gene_index` with `t2g` rewritten to identity + `mt_transcripts.txt` (minutes); the index alignment uses |

### `work/` — computed, dataset-centric

`work/<dataset>/{pipeline,analysis}/` for `arrigoni` and `ding_cortex_2`.

- `work/<dataset>/pipeline/` — the Nextflow run: `run_pipeline.sh`, `samplesheet.csv`,
  `nextflow.config`, `custom.config`, `.nextflow.log`, and `results/` (alevin quant +
  preprocessed matrices). Was `runs/<dataset>/`.
- `work/<dataset>/analysis/` — the R analysis workspace: `raw_matrix.seurat.rds` (the
  pipeline→analysis handoff, written by `unfiltered_dir`), `objects/`, `plots/`, `logs/`
  and the DTU tables. Was `data/project_files/<dataset>/`.

`work/` is gitignored and exists only on athena; `rm -rf work/<dataset>` reclaims all
regenerable space for one dataset.

### `scratch/`

Obsolete leftovers kept for now (`tau_sweep/` from the removed standalone script,
`publish_results/` staging for `scripts/collect_results.sh`). Gitignored.

> Two further Ding runs (`runs/ding/pbmc1/`, `runs/ding/brain1/`) produced no reported
> table and were deleted 2026-09-22; re-create them from the ingest instructions if
> ever needed.

## Disk pressure

- `/data` — 18 TB, 13 TB free (25 % used) as of 2026-09-22.
- `/` (and `/home`) — 436 GB, **30 GB free (93 % used)**. Keep new scratch under
  `/data`, not `$HOME`.
