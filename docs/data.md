# Data

Where the data comes from, and where it lives on athena. The processed objects
themselves are **not** in the repository (multi-GB); they stay on athena under
`work/<dataset>/analysis/`.

## The two datasets

### Arrigoni 2023 — human lung-cancer cell lines

| | |
| :--- | :--- |
| GEO | **GSE243665** |
| Organism / assembly | *Homo sapiens*, **GRCh38** (Ensembl release 102) |
| Assay | 10x Chromium, `10xv1` |
| Samples | 8: A549, CCL-185-IG, CRL5868, DV90, HCC78, HTB178, PBMCs, PC9 |
| Level used | transcript (isoform) |
| SRA runs (ingested) | `SRR26127904`–`SRR26127911` (8) |
| Samplesheet | `athena:work/arrigoni/pipeline/samplesheet.csv` (sample `banchmark_mix`) |
| Analysis workspace | `athena:work/arrigoni/analysis/` |

This is a benchmark mixture of eight cell lines labelled by GEO barcode files;
those same barcodes are the `Known_Cell_Types` clusterization used for DEA.

### Ding cortex_2 — mouse cortex

| | |
| :--- | :--- |
| GEO | **GSE132044** |
| Organism / assembly | *Mus musculus*, **GRCm39** (Ensembl release 102) |
| Assay | 10x Chromium v2, `10XV2` ("Cortex2" cells) |
| Level used | gene **and** transcript (compared) |
| SRA runs (ingested) | `SRR9170683`, `SRR9170684`, `SRR9170686`, `SRR9170687`, `SRR9170691`, `SRR9170692`, `SRR9170693`, `SRR9170886` (8) |
| Samplesheet | `athena:work/ding_cortex_2/pipeline/samplesheet.csv` (sample `cortex_2`) |
| Analysis workspace | `athena:work/ding_cortex_2/analysis/` |

The cortex run is the gene-vs-transcript comparison: the same cells are analysed
at both levels and the DTU candidate tables are intersected (step `08`). The
cortex_2 cells arrive already QC-filtered; the barcode list is
`data/inputs/geo_metadata/ding_cortex_2/clean_Cortex2_QC_barcodes.tsv.gz`.

## Re-downloading

Everything is fetched from public sources by the Nextflow half. On athena, from
inside a run directory (`work/` is gitignored and exists only there):

```bash
cd /data/lorenzo_delitala/work/<dataset>/pipeline
./run_pipeline.sh          # nextflow run .../src/pipeline/main.nf -c nextflow.config \
                           #   -profile singularity -resume
```

This re-downloads SRA runs from NCBI/ENA, builds the simpleaf index from Ensembl
release 102 FASTA/GTF, aligns with `nf-core/scrnaseq` 4.1.0, and stages the raw
matrix. See `src/analysis/README.md` for the rerun recipe and the parity gate.

Third-party papers are cited, not redistributed; the COTAN paper and
documentation PDFs are **not** shipped in this repository.

## athena layout

`athena` is the university machine — everything lives there. Root:
`/data/lorenzo_delitala` (~430 GB total). Sizes measured 2026-09-22.

| Path | Size | Holds | Regenerable? |
| :--- | ---: | :--- | :--- |
| `src/` | 3.6 MB | the git working tree (this repo: code + configs) | no |
| `results/` | 159 MB | curated published outputs (tracked); see `results/README.md` | no |
| `docs/`, `scripts/`, `envs/` | <1 MB | tracked code + docs | no |
| `data/inputs/` | ~250 GB | downloaded external data (see below) | re-download |
| `data/built/` | ~18 GB | indices made from `data/inputs/reference` | rebuild (hours) |
| `work/` | ~125 GB | computed pipeline + analysis output (see below) | re-run |
| `COTAN/` | 138 MB | COTAN source clone (pinned commit) | re-clonable, but keep |
| `.conda/` | 19 GB | the `cotanisoform-*` conda envs | recreate with `conda env create` — keep |
| `.cache/` | 3.1 GB | `ncbi/refseq` 635 MB, `singularity/` 2.4 GB | — |
| `scratch/` | empty | gitignored staging area for `collect_results.sh` | — |

### `data/inputs/` — downloaded, not computed

| Path | Size | Contents |
| :--- | ---: | :--- |
| `data/inputs/fastqs/<dataset>/` | 248 GB | per-dataset FASTQs (re-downloadable from SRA) |
| `data/inputs/geo_metadata/<dataset>/` | 345 MB | GEO barcode files for QC and cell types |
| `data/inputs/reference/{GRCh38,GRCm39}/` | 1.7 GB | Ensembl 102 `genome.fa.gz` + `annotation.gtf.gz` |

### `data/built/` — made from `data/inputs/reference`

| Path | Size | Made by |
| :--- | ---: | :--- |
| `data/built/<asm>/gene_index/` | 8.8 GB | `simpleaf index` (pipeline `2.2`, hours); holds the real `t2g_3col.tsv` + `gene_id_to_name.tsv` used by step 00 |
| `data/built/<asm>/transcript_index/` | 8.8 GB | `2.3_index_apply_cheat.sh` — copy of `gene_index` with `t2g` rewritten to identity + `mt_transcripts.txt` (minutes); the index alignment uses |

### `work/` — computed, dataset-centric

`work/<dataset>/{pipeline,analysis}/` for `arrigoni` and `ding_cortex_2`.

- `work/<dataset>/pipeline/` — the Nextflow run: `run_pipeline.sh`, `samplesheet.csv`,
  `nextflow.config`, `custom.config`, `.nextflow.log`, and `results/` (alevin quant).
- `work/<dataset>/analysis/` — the R analysis workspace, grouped by role:
  `raw_matrix.seurat.rds` (the pipeline→analysis handoff), `objects/` (COTAN/Seurat
  chain), `plots/`, `logs/`, `tables/` (DTU tables + feature/barcode maps).

`work/` is gitignored and exists only on athena; `rm -rf work/<dataset>` reclaims all
regenerable space for one dataset.

### `results/` — published (tracked)

`results/<dataset>/{tables,plots,logs}/`, mirrored from `work/<dataset>/analysis/` by
`scripts/collect_results.sh`. The `logs/` are the **immutable** record of the released
runs (the working logs under `work/` are overwritten by re-runs). See
`results/README.md`.

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

## Disk pressure

- `/data` — 18 TB, 13 TB free (25 % used) as of 2026-09-22.
- `/` (and `/home`) — 436 GB, **30 GB free (93 % used)**. Keep new scratch under
  `/data`, not `$HOME`.
