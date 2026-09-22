# Environments

Conda definitions for the two things that need one on athena: the **R analysis
environment** and the **Nextflow launcher**. Everything the pipeline actually computes
externally (aligner, indexer, quantifier) runs inside Singularity containers and is *not*
listed here.

## Why conda at all

athena has no `sudo` and `/data` is root-owned, so the system package manager is not
available. Conda was the only way to install R, the R libraries and Nextflow without root.
This file is **not** the pipeline's dependency mechanism — `nextflow.config` and the
Singularity images are. Treat conda as "the machine's tooling", not "the pipeline's tools".

## The files

| File | Purpose |
| :--- | :--- |
| `analysis.yml` | R 4.5.3 + the R packages used by `cotanisoform/`, `analysis/` and `scripts/`. |
| `pipeline.yml` | Nextflow (the launcher only) + a JDK + `pigz`. |

`COTAN` itself is deliberately **not** in `analysis.yml`: it is installed from a pinned
GitHub commit by [`../scripts/install_deps.R`](../scripts/install_deps.R), because the
commit is the reproducibility-critical part.

## Creating the environments (on athena)

```bash
cd /data/lorenzo_delitala/src          # or the cleanup checkout
conda env create -f envs/analysis.yml
conda env create -f envs/pipeline.yml

conda activate cotanisoform-analysis
Rscript scripts/install_deps.R         # installs COTAN at the pinned commit
R CMD INSTALL cotanisoform             # this repository's package
```

Environments are created under `/data/lorenzo_delitala/.conda/envs/`. conda also reports
that path as `/home/lorenzo_delitala/.conda/envs/` — the two are the **same directory**
(bind mount), so either spelling works.

Call the interpreter explicitly when not activating:

```bash
/data/lorenzo_delitala/.conda/envs/cotanisoform-analysis/bin/Rscript analysis/run_all.R \
  --config analysis/config/arrigoni.yaml
```

## What the pipeline does *not* get from here

`simpleaf`, `piscem`, `salmon`, `alevin-fry` and `10x_bamtofastq` are provided by the
Singularity containers declared in `src/pipeline/nextflow.config` (nf-core/scrnaseq).
They must never be added to `pipeline.yml`. `sra-tools` is likewise absent — the ingest
step also runs in a container.

## Deliberately dropped from the old `deli` env

The old `deli` env mixed analysis, launcher and dev concerns. These are not carried over:

| Dropped | Reason |
| :--- | :--- |
| `pytorch`, `torchvision`, `torchaudio`, `torchcodec`, `cpuonly` | no tracked R or analysis code uses them; `torch` is only a COTAN *Suggests* |
| `simpleaf`, `piscem`, `salmon`, `alevin-fry`, `10x_bamtofastq` | provided by Singularity containers |
| `msmtp`, `rust`, `python-dotenv` | scratch installs, unused |
| `r-languageserver`, `r-httpgd` | VS Code conveniences for editing on athena; editing happens on the Mac |
| `r-usethis` | arrives transitively via `r-devtools` |
| `r-here` | used nowhere in the tracked code |
| `bioconductor-scuttle` | not in the running env, used nowhere |
| `torch`, `safetensors`, `AsioHeaders`, `coro` | hand-installed, unused |

Five packages that COTAN *requires* were installed by hand into the old env and were **not
tracked by conda**: `conflicted`, `zeallot`, `ggthemes`, `dendextend`, `BiocStyle`. A
recreated env without them cannot load COTAN. They are now explicit conda dependencies
(`r-conflicted`, `r-zeallot`, `r-ggthemes`, `r-dendextend`, `bioconductor-biocstyle`).
`bioconductor-dendextend` does not exist on bioconda; `dendextend` is a CRAN package and
comes from `r-dendextend` on conda-forge.

`conflicted`, `zeallot` and `parallelly` are also used directly by `cotanisoform`
(see `cotanisoform/DESCRIPTION`).

## Versions

`r-base=4.5.3` and the COTAN commit in `install_deps.R` are the load-bearing pins. Other
versions float with current repodata; the original env had `r-matrix` 1.7_5, `r-lintr`
3.3.0 and `r-roxygen2` 8.0.0, and a fresh solve now picks 1.7_6 / 3.4.0 / 8.1.0. Pin those
too if a byte-exact reproduction is ever needed.

## Verifying a change to these files

```bash
conda env create -f envs/analysis.yml --dry-run   # solves, creates nothing
conda env create -f envs/pipeline.yml --dry-run
```

A dry-run only proves the *specs* solve; it does not prove COTAN can load. After changing
`analysis.yml`, also check that the solved set still covers every entry of COTAN's
`Imports:`. The `r-conflicted`/`r-zeallot`/`r-ggthemes`/`r-dendextend`/`bioconductor-biocstyle`
entries above exist exactly because the old list passed the dry-run while still failing to
load COTAN.
