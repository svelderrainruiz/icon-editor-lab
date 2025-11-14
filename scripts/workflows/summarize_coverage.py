#!/usr/bin/env python3
"""Append a coverage summary to the GitHub step summary."""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: summarize_coverage.py <coverage_xml> <summary_path>")
    coverage_xml, summary_path = sys.argv[1:3]
    root = ET.parse(coverage_xml).getroot()
    pct = 0.0
    rate_attr = root.get("line-rate")
    if rate_attr is not None:
        try:
            pct = round(float(rate_attr) * 100, 2)
        except (TypeError, ValueError):
            pct = 0.0
    covered = root.get("lines-covered") or "<unknown>"
    total = root.get("lines-valid") or "<unknown>"
    flagged = []
    for cls in root.findall(".//class"):
        try:
            rate = float(cls.get("line-rate", "0"))
        except (TypeError, ValueError):
            rate = 0.0
        if rate < 1.0:
            flagged.append(cls.get("filename") or cls.get("name") or "<unnamed>")
    lines = [
        "### Ubuntu Coverage",
        "",
        f"- Line rate: {pct}%",
        f"- Covered lines: {covered}/{total}",
    ]
    if flagged:
        lines.append(f"- Files < 100% coverage: {', '.join(flagged)}")
    summary = "\n".join(lines) + "\n"
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write(summary)
    else:
        print(summary, end="")


if __name__ == "__main__":
    main()
