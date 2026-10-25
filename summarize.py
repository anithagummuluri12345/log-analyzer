#!/usr/bin/env python3
"""summarize.py

Parses a validation log and prints a failure-analysis summary:
counts by level, errors by module, repeated error patterns, the first and
last error, and whether errors are concentrated in the second half of the run.

Usage:
    python3 summarize.py <logfile> [-o report.txt] [--json summary.json]
"""

import argparse
import json
import re
import sys
from collections import Counter

LINE_RE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2}) (?P<time>\d{2}:\d{2}:\d{2}) "
    r"\[(?P<level>[A-Z]+)\] (?P<module>\w+): (?P<message>.*)$"
)


def normalize(message):
    """Replace hex values and numbers so similar errors group together."""
    message = re.sub(r"0x[0-9a-fA-F]+", "<HEX>", message)
    return re.sub(r"\d+", "<N>", message)


def parse_log(path):
    """Return (entries, skipped). Each entry is a dict with a line_no key."""
    entries, skipped = [], 0
    with open(path, encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            match = LINE_RE.match(line.strip())
            if not match:
                skipped += 1
                continue
            entry = match.groupdict()
            entry["line_no"] = line_no
            entries.append(entry)
    return entries, skipped


def describe(entry):
    if entry is None:
        return None
    return {
        "line_no": entry["line_no"],
        "timestamp": f"{entry['date']} {entry['time']}",
        "module": entry["module"],
        "message": entry["message"],
    }


def summarize(entries):
    levels = Counter(e["level"] for e in entries)
    errors = [e for e in entries if e["level"] == "ERROR"]
    mid = len(entries) // 2

    return {
        "total_entries": len(entries),
        "levels": dict(levels),
        "error_rate_percent": round(100 * len(errors) / len(entries), 2) if entries else 0.0,
        "errors_by_module": dict(Counter(e["module"] for e in errors).most_common()),
        "top_error_patterns": Counter(normalize(e["message"]) for e in errors).most_common(5),
        "first_error": describe(errors[0] if errors else None),
        "last_error": describe(errors[-1] if errors else None),
        "errors_first_half": sum(1 for e in entries[:mid] if e["level"] == "ERROR"),
        "errors_second_half": sum(1 for e in entries[mid:] if e["level"] == "ERROR"),
    }


def format_report(log_name, skipped, s):
    lines = [
        f"Log file: {log_name}",
        f"Parsed entries: {s['total_entries']} (skipped {skipped} unrecognised lines)",
        f"Error rate: {s['error_rate_percent']}%",
        "",
        "Entries by level:",
    ]
    for level, count in sorted(s["levels"].items()):
        lines.append(f"  {level:<6}{count}")

    lines += ["", "Errors by module:"]
    for module, count in s["errors_by_module"].items():
        lines.append(f"  {module:<12}{count}")

    lines += ["", "Top repeated error patterns:"]
    for pattern, count in s["top_error_patterns"]:
        lines.append(f"  {count:>3} x  {pattern}")

    for label, key in (("First error", "first_error"), ("Last error", "last_error")):
        e = s[key]
        lines += ["", f"{label}:"]
        if e:
            lines.append(f"  line {e['line_no']} at {e['timestamp']} [{e['module']}] {e['message']}")
        else:
            lines.append("  none")

    lines += [
        "",
        "Errors in first half of log : " + str(s["errors_first_half"]),
        "Errors in second half of log: " + str(s["errors_second_half"]),
    ]
    if s["errors_second_half"] > 2 * max(s["errors_first_half"], 1):
        lines.append("Hypothesis: failures start partway through the run. Inspect the first error and the entries just before it.")

    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description="Summarize a validation log.")
    parser.add_argument("log_file", help="path to the log file")
    parser.add_argument("-o", "--output", help="write the text report to this file")
    parser.add_argument("--json", help="also write the summary as JSON to this file")
    args = parser.parse_args()

    try:
        entries, skipped = parse_log(args.log_file)
    except FileNotFoundError:
        sys.exit(f"File not found: {args.log_file}")

    if not entries:
        sys.exit("No valid log entries found.")

    summary = summarize(entries)
    report = format_report(args.log_file, skipped, summary)
    print(report)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(report)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(summary, f, indent=2)


if __name__ == "__main__":
    main()
