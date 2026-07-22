#!/bin/bash
# Usage: ./check_layout.sh <srr_id>
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <srr_id>" >&2
    exit 1
fi

srr_id=$1

# Store the result in a variable instead of piping directly to stdout
layout=$(curl -f -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${srr_id}&result=read_run&fields=library_layout" \
| tail -n +2 \
| cut -f2 \
| tr -d '\n\r')

# Check if the result is empty
if [ -z "$layout" ]; then
    echo "UNKNOWN"
    # echo "Warning: '${srr_id}' not found in ENA. It may be invalid or too new." >&2
    exit 1
fi

echo "$layout"