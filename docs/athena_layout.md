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

Root: `/data/lorenzo_delitala` (~450 GB total).

| Path | Size | Holds | Safe to delete? |
| :--- | ---: | :--- | :--- |
| `src/` | 3.6 MB | the git working tree (this repo) | no |
| `results/` | 158 MB | curated published outputs (tracked) | no |
| `docs/`, `scripts/`, `envs/` | <1 MB | tracked code + docs | no |
| `.conda/` | 19 GB | the `cotanisoform-*` conda envs | recreate with `conda env create` — keep |
| `COTAN/` | 138 MB | COTAN source clone (pinned commit) | re-clonable, but keep |
| `data/` | 295 GB | see below | partly |
| `runs/` | 133 GB | `arrigoni/` 108 GB + `ding/cortex_2/` 26 GB — run dirs + preprocessing bulk | no |
| `.cache/` | 3.1 GB | `ncbi/refseq` 635 MB, `singularity/` 2.4 GB (the SRA prefetch cache was deleted 2026-09-22) | — |
| `/home/lorenzo_delitala/cleanup-checkout` | 280 MB | scratch clone that S8 deletes | yes (at S8) |

### `data/`

| Path | Size | Contents |
| :--- | ---: | :--- |
| `data/fastqs/` | 248 GB | per-dataset FASTQs (re-downloadable) |
| `data/project_files/` | 25 GB | per-dataset analysis workspace (`arrigoni/` 15 GB, `ding/` 11 GB) |
| `data/genomes/` | 20 GB | `GRCh38/` 12 GB, `GRCm39/` 7.4 GB — Ensembl release 102 indices |
| `data/test/` | 2.7 GB | see below |
| `data/geo_metadata/` | 345 MB | GEO barcode files for QC and cell types (tracked? no — small, keep) |

`data/test/`:

| File | Size | Note |
| :--- | ---: | :--- |
| `cotan_coex.rds` | **2.78 GB** | Stored final COTAN object. **Not** read by `src/analysis/config/*.yaml` or `scripts/verify_dtu_parity.R` (which use `calculated.cotan.rds` and `clustered.transcript.with_gene_labels.rds`), so it is not a parity input. Kept as the last coexistence-state checkpoint. **Never delete.** |
| `b2sample.tsv` | 19 MB | two-sample test table |
| `gdi_distribution.pdf` | 497 KB | scratch GDI plot (also in `results/`) |

### `runs/`

Per-dataset dirs `runs/arrigoni/` and `runs/ding/cortex_2/` — the two reported
datasets. Each holds `run_pipeline.sh`, `samplesheet.csv`, `nextflow.config`,
`custom.config`, `.nextflow.log` and a `results/` tree (downloaded data, references,
index, preprocessed matrices). `runs/` is gitignored and exists only on athena. The
handoff artefact to `src/analysis/` is a Seurat object under
`data/project_files/<dataset>/`.

> Two further Ding runs, `runs/ding/pbmc1/` (395 GB) and `runs/ding/brain1/`
> (108 GB), were completed (2026-06-24, no failures) but produced no reported table
> and no analysis workspace. Both were **deleted 2026-09-22** with the SRA download
> cache; re-create them from the ingest instructions if ever needed.

> `runs/` paths in old scratch scripts say `arrigoni2023`; the real directory is
> `runs/arrigoni/`.

## Disk pressure

- `/data` — 18 TB, 13 TB free (25 % used) as of 2026-09-22.
- `/` (and `/home`) — 436 GB, **30 GB free (93 % used)**. Keep new scratch under
  `/data`, not `$HOME`.
