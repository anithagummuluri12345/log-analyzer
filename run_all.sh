#!/usr/bin/env bash
# run_all.sh
# Runs the whole pipeline: generate a log -> analyze with Bash -> summarize with Python.
#
# Usage: ./run_all.sh

set -euo pipefail
cd "$(dirname "$0")"

PYTHON=$(command -v python3 || command -v python || true)
if [[ -z "$PYTHON" ]]; then
  echo "Python is not installed or not on PATH." >&2
  exit 1
fi

mkdir -p output

bash generate_sample_log.sh output/sample_validation.log 500

echo
bash analyze_log.sh output/sample_validation.log | tee output/bash_report.txt

echo
"$PYTHON" summarize.py output/sample_validation.log \
  -o output/python_report.txt --json output/summary.json

echo "Reports saved in the output/ folder."
