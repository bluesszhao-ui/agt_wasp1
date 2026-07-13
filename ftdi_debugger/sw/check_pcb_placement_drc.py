#!/usr/bin/env python3
"""Validate the expected KiCad DRC state for the unrouted Rev A placement."""

from __future__ import annotations

from collections import Counter
from pathlib import Path
import argparse
import re
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()

    report = args.report.read_text(encoding="utf-8")
    categories = Counter(
        match.group(1)
        for match in re.finditer(r"^\[([^]]+)\]:", report, flags=re.MULTILINE)
    )
    unconnected = categories.pop("unconnected_items", 0)
    library_mismatches = categories.pop("lib_footprint_mismatch", 0)

    if unconnected == 0:
        print("FAIL placement report contains no expected unrouted connections", file=sys.stderr)
        return 1
    if library_mismatches != 2:
        print(
            f"FAIL expected two connector library overrides, observed {library_mismatches}",
            file=sys.stderr,
        )
        return 1
    for ref in ("J1", "J2"):
        if not re.search(rf"封装 {ref}$|Footprint {ref}$", report, flags=re.MULTILINE):
            print(f"FAIL missing documented library override for {ref}", file=sys.stderr)
            return 1
    if categories:
        print(f"FAIL unexpected placement DRC categories: {dict(categories)}", file=sys.stderr)
        return 1
    if "** Found 0 Footprint errors **" not in report:
        print("FAIL footprint error summary is not zero", file=sys.stderr)
        return 1

    print(
        "PASS PCB placement DRC: "
        f"{unconnected} expected unrouted items, 2 documented connector overrides"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
