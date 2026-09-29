#!/bin/bash
# Usage: ./download_ref.sh <fasta_url> <gtf_url>
set -euo pipefail

fasta_url=$1
gtf_url=$2

# Handle potential 404 on primary_assembly by falling back to toplevel
if wget -q --spider "${fasta_url}"; then
    wget -q -O genome.fa.gz "${fasta_url}"
else
    wget -q -O genome.fa.gz "${fasta_url/primary_assembly/toplevel}"
fi

wget -q -O annotation.gtf.gz "${gtf_url}"