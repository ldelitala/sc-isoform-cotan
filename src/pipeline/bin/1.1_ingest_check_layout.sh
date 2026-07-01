#!/bin/bash
# Usage: ./check_layout.sh <srr_id>
set -euo pipefail

srr_id=$1

curl -f -s "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${srr_id}&result=read_run&fields=library_layout" \
| tail -n +2 \
| cut -f2 \
| tr -d '\n\r'