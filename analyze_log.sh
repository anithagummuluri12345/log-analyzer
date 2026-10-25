#!/usr/bin/env bash
# analyze_log.sh
# First-pass log analysis using grep, awk, sed, sort and uniq.
#
# Usage: ./analyze_log.sh <logfile>

set -uo pipefail

LOG="${1:-}"
if [[ -z "$LOG" || ! -f "$LOG" ]]; then
  echo "Usage: $0 <logfile>" >&2
  exit 1
fi

echo "=== Log analysis: $LOG ==="
echo "Total lines: $(wc -l < "$LOG")"
echo

echo "--- Lines per level ---"
for level in INFO WARN ERROR; do
  count=$(grep -c "\[$level\]" "$LOG")
  printf '%-6s %s\n' "$level" "$count"
done
echo

echo "--- Errors per module ---"
grep "\[ERROR\]" "$LOG" | awk '{gsub(":", "", $4); print $4}' | sort | uniq -c | sort -rn
echo

echo "--- Errors per minute ---"
grep "\[ERROR\]" "$LOG" | awk '{split($2, t, ":"); print t[1] ":" t[2]}' | sort | uniq -c
echo

echo "--- Most common error patterns ---"
grep "\[ERROR\]" "$LOG" \
  | sed -E 's/^.*\] [a-z]+: //; s/0x[0-9a-fA-F]+/<HEX>/g; s/[0-9]+/<N>/g' \
  | sort | uniq -c | sort -rn | head -n 5
echo

echo "--- First error (line number:entry) ---"
grep -n -m 1 "\[ERROR\]" "$LOG"
echo

echo "--- Last error (line number:entry) ---"
grep -n "\[ERROR\]" "$LOG" | tail -n 1
