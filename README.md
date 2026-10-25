# Log Analyzer: Shell and Python Debug Automation

A small toolkit for analyzing test or validation logs. It finds where failures start, which modules fail most, and which errors repeat. It combines Bash for quick first-pass analysis with Python for deeper summaries and reports.

## What it does

| File | Purpose |
|---|---|
| `generate_sample_log.sh` | Creates a reproducible sample validation log (errors become frequent partway through, simulating a failure) |
| `analyze_log.sh` | First-pass analysis with `grep`, `awk`, `sed`, `sort`, `uniq`: counts per level, errors per module and per minute, common error patterns, first and last error |
| `summarize.py` | Parses the log with regular expressions, groups similar errors (hex values and numbers are normalized), reports the first and last error, and compares the first half of the run with the second half. Writes a text report and JSON |
| `run_all.sh` | Runs the whole pipeline and saves reports in `output/` |

## Requirements

- Linux, macOS, WSL, or Git Bash on Windows
- Python 3.8+ (standard library only, nothing to install)

## How to run

```bash
bash run_all.sh
```

Or run each step yourself:

```bash
bash generate_sample_log.sh output/sample_validation.log 500
bash analyze_log.sh output/sample_validation.log
python3 summarize.py output/sample_validation.log -o output/report.txt --json output/summary.json
```

Use your own log by passing its path. The log format is:

```
2026-09-19 10:00:18 [ERROR] memory: checksum error in block 2
```

## Sample output

Running `bash run_all.sh` on the generated 500-line log prints the following.

### Bash analysis (`analyze_log.sh`)

```
--- Lines per level ---
INFO   406
WARN   54
ERROR  40

--- Errors per module ---
     11 boot
      9 uart
      8 memory
      5 cache
      4 interrupt
      3 timer

--- Most common error patterns ---
     13 unexpected value <HEX> in status register
     10 checksum error in block <N>
      9 timeout waiting for ack after <N> ms
      8 data mismatch at address <HEX>

--- First error (line number:entry) ---
10:2026-09-19 10:00:18 [ERROR] memory: checksum error in block 2
```

### Python summary (`summarize.py`)

```
Parsed entries: 500 (skipped 0 unrecognised lines)
Error rate: 8.0%

Top repeated error patterns:
   13 x  unexpected value <HEX> in status register
   10 x  checksum error in block <N>
    9 x  timeout waiting for ack after <N> ms
    8 x  data mismatch at address <HEX>

First error:
  line 10 at 2026-09-19 10:00:18 [memory] checksum error in block 2

Errors in first half of log : 12
Errors in second half of log: 28
Hypothesis: failures start partway through the run. Inspect the first error and the entries just before it.
```
## Debugging workflow this supports

1. Count errors by level and module to see where the problem is.
2. Group repeated errors by pattern so one root cause is not counted many times.
3. Find the first error, because later errors are often side effects of it.
4. Check whether errors are spread evenly or start at a specific point.

## Notes

- The sample log is generated with a fixed seed, so every run gives the same file.
- Lines that do not match the log format are skipped and counted in the report.

## Ideas to extend

- Support more log formats through command-line options
- Add a `--level` filter and a `--since` time filter
- Export a CSV of all errors
- Add unit tests for `normalize()` and `parse_log()`
