#!/usr/bin/env bash
# Stage the curated, Git-friendly result artifacts from a run into scratch/publish_results.
#
# Run ON ATHENA from anywhere (the script cd's to the repo root).
# Large intermediate objects (*.rds COTAN/Seurat matrices) and raw data are
# intentionally excluded — see results/README.md.
#
# After running this, from the Mac:
#   rsync -a athena:/data/lorenzo_delitala/scratch/publish_results/ results/
#   git add results && git commit -m "Update results" && git push github master && git push origin master
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=work
OUT=scratch/publish_results

rm -rf "$OUT"
mkdir -p "$OUT/arrigoni/tables" "$OUT/arrigoni/plots" "$OUT/arrigoni/logs" \
         "$OUT/ding_cortex_2/tables" "$OUT/ding_cortex_2/plots" "$OUT/ding_cortex_2/logs"

# arrigoni — human cell lines (GSE243665), transcript level
cp "$SRC/arrigoni/analysis/tables/"*                           "$OUT/arrigoni/tables/" 2>/dev/null || true
cp -rL "$SRC/arrigoni/analysis/plots/."    "$OUT/arrigoni/plots/"    2>/dev/null || true
cp -rL "$SRC/arrigoni/analysis/logs/."     "$OUT/arrigoni/logs/"     2>/dev/null || true

# ding cortex_2 — mouse cortex, gene vs transcript comparison
cp "$SRC/ding_cortex_2/analysis/tables/"*                       "$OUT/ding_cortex_2/tables/" 2>/dev/null || true
cp -rL "$SRC/ding_cortex_2/analysis/plots/."    "$OUT/ding_cortex_2/plots/"    2>/dev/null || true
cp -rL "$SRC/ding_cortex_2/analysis/logs/."     "$OUT/ding_cortex_2/logs/"     2>/dev/null || true

echo "Staged $(find "$OUT" -type f | wc -l) files, $(du -sh "$OUT" | cut -f1) into $OUT"
