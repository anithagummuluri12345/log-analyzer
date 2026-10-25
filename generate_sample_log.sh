#!/usr/bin/env bash
# generate_sample_log.sh
# Creates a fake hardware-validation style log so the analysis scripts have data to work on.
# Errors are rare at first and become common after 60% of the log (a simulated failure).
#
# Usage: ./generate_sample_log.sh [output_file] [number_of_lines]

set -euo pipefail

OUT="${1:-sample_validation.log}"
LINES="${2:-500}"
RANDOM=42   # fixed seed: the same log is produced on every run

MODULES=(uart cache memory boot timer interrupt)
INFO_MSGS=("test started" "test completed" "register read ok" "self check passed" "link established")
WARN_MSGS=("retrying operation" "response slower than expected" "buffer nearly full")

# Sets ERR_MSG to a random error message (no subshell, so the fixed seed stays reproducible).
pick_error() {
  local hex
  case $((RANDOM % 4)) in
    0) printf -v hex '%08x' $((RANDOM * RANDOM))
       ERR_MSG="data mismatch at address 0x$hex" ;;
    1) ERR_MSG="timeout waiting for ack after $((RANDOM % 50 + 10)) ms" ;;
    2) ERR_MSG="checksum error in block $((RANDOM % 16))" ;;
    3) printf -v hex '%04x' $((RANDOM % 65536))
       ERR_MSG="unexpected value 0x$hex in status register" ;;
  esac
}

onset=$((LINES * 60 / 100))
: > "$OUT"

for ((i = 0; i < LINES; i++)); do
  t=$((36000 + i * 2))   # start at 10:00:00, one entry every 2 seconds
  printf -v ts '2026-09-19 %02d:%02d:%02d' $((t / 3600)) $(((t % 3600) / 60)) $((t % 60))

  module=${MODULES[RANDOM % ${#MODULES[@]}]}
  roll=$((RANDOM % 100))

  if ((i < onset)); then error_limit=3; else error_limit=15; fi

  if ((roll < error_limit)); then
    level=ERROR
    pick_error
    msg=$ERR_MSG
  elif ((roll < error_limit + 12)); then
    level=WARN
    msg=${WARN_MSGS[RANDOM % ${#WARN_MSGS[@]}]}
  else
    level=INFO
    msg=${INFO_MSGS[RANDOM % ${#INFO_MSGS[@]}]}
  fi

  echo "$ts [$level] $module: $msg" >> "$OUT"
done

echo "Wrote $LINES lines to $OUT"
