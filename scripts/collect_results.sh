#!/usr/bin/env bash
# Stage the curated, Git-friendly result artifacts from a run into data/publish_results.
#
# Run ON ATHENA from anywhere (the script cd's to the repo root).
# Large intermediate objects (*.rds COTAN/Seurat matrices) and raw data are
# intentionally excluded — see results/README.md.
#
# After running this, from the Mac:
#   rsync -a athena:/data/lorenzo_delitala/data/publish_results/ results/
#   git add results && git commit -m "Update results" && git push github master && git push origin master
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=data/project_files
OUT=data/publish_results

rm -rf "$OUT"
mkdir -p "$OUT/arrigoni" "$OUT/ding_cortex_2"

# arrigoni — human cell lines (GSE243665), transcript level
cp "$SRC/arrigoni/dtu_candidates.csv"            "$OUT/arrigoni/" 2>/dev/null || true
cp "$SRC/arrigoni/t2gene_name.tsv"               "$OUT/arrigoni/" 2>/dev/null || true
cp "$SRC/arrigoni/GSE243665_combined_QC_barcodes.tsv" "$OUT/arrigoni/" 2>/dev/null || true
cp -rL "$SRC/arrigoni/plots"    "$OUT/arrigoni/plots"    2>/dev/null || true
cp -rL "$SRC/arrigoni/Rscripts" "$OUT/arrigoni/Rscripts" 2>/dev/null || true
cp -rL "$SRC/arrigoni/logs"     "$OUT/arrigoni/logs"     2>/dev/null || true

# ding cortex_2 — mouse cortex, gene vs transcript comparison
cp "$SRC"/ding/cortex_2/dtu_*.csv            "$OUT/ding_cortex_2/" 2>/dev/null || true
cp "$SRC"/ding/cortex_2/dtu_*.rds            "$OUT/ding_cortex_2/" 2>/dev/null || true
cp "$SRC/ding/cortex_2/objects/t2gene_name.tsv" "$OUT/ding_cortex_2/" 2>/dev/null || true
cp -rL "$SRC/ding/cortex_2/plots"    "$OUT/ding_cortex_2/plots"    2>/dev/null || true
cp -rL "$SRC/ding/cortex_2/Rscripts" "$OUT/ding_cortex_2/Rscripts" 2>/dev/null || true
cp -rL "$SRC/ding/cortex_2/logs"     "$OUT/ding_cortex_2/logs"     2>/dev/null || true

# scratch/test
cp data/test/gdi_distribution.pdf "$OUT/" 2>/dev/null || true

echo "Staged $(find "$OUT" -type f | wc -l) files, $(du -sh "$OUT" | cut -f1) into $OUT"
