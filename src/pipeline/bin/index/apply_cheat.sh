#!/bin/bash
# Usage: ./apply_cheat.sh <source_dir> <output_name>
set -euo pipefail

src=$1
out=$2

cp -rL "${src}" "${out}"
cd "${out}/index"

# Extract MT transcripts
awk -F'\t' 'NR==FNR {if ($2 ~ /^[Mm][Tt][-|_]/) mt[$1]=1; next} {if ($2 in mt) print $1}' \
    gene_id_to_name.tsv t2g_3col.tsv > mt_transcripts.txt

# Apply Transcript Cheat
awk -F'\t' 'BEGIN {OFS="\t"} {print $1, $1, $3}' t2g_3col.tsv > tmp.tsv
mv tmp.tsv t2g_3col.tsv

rm -f gene_id_to_name.tsv