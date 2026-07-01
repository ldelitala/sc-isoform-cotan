#!/bin/bash
# Usage: ./build_index.sh <fasta> <gtf> <cpus> <output_name>
set -euo pipefail

fasta=$1
gtf=$2
cpus=$3
out_name=$4

export ALEVIN_FRY_HOME=$PWD
simpleaf set-paths

simpleaf index -f "${fasta}" -g "${gtf}" -o "${out_name}" -t "${cpus}"