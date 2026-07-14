#!/usr/bin/env python3
"""Cross-check the Rev A production BOM against the committed KiCad board."""

from __future__ import annotations

from collections import Counter
from pathlib import Path
import argparse
import csv
import re
import sys

import pcbnew


REQUIRED_COLUMNS = (
    "refdes", "quantity", "population", "function", "manufacturer",
    "manufacturer_part_number", "approved_alternate", "footprint",
    "lifecycle_status", "lifecycle_checked", "source_url", "notes",
)
RELEASE_DATE = "2026-07-14"


def expand_refdes(expression: str) -> list[str]:
    """Expand slash-separated references and same-prefix numeric ranges."""
    references: list[str] = []
    for token in expression.split("/"):
        range_match = re.fullmatch(r"([A-Z][A-Z0-9_]*?)(\d+)-([A-Z][A-Z0-9_]*?)(\d+)", token)
        if range_match:
            left_prefix, left_number, right_prefix, right_number = range_match.groups()
            if left_prefix != right_prefix or int(left_number) > int(right_number):
                raise AssertionError(f"invalid reference range: {token}")
            references.extend(
                f"{left_prefix}{number}"
                for number in range(int(left_number), int(right_number) + 1)
            )
        elif re.fullmatch(r"[A-Z][A-Z0-9_]*", token):
            references.append(token)
        else:
            raise AssertionError(f"invalid reference expression token: {token}")
    return references


def audit_bom(board_path: Path, bom_path: Path) -> Counter[str]:
    """Require complete reference, footprint, population, and sourcing coverage."""
    board = pcbnew.LoadBoard(str(board_path.resolve()))
    board_footprints = {
        str(footprint.GetReference()): footprint
        for footprint in board.GetFootprints()
    }
    with bom_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if tuple(reader.fieldnames or ()) != REQUIRED_COLUMNS:
            raise AssertionError(f"production BOM columns differ: {reader.fieldnames}")
        rows = list(reader)

    bom_refs: dict[str, dict[str, str]] = {}
    populations: Counter[str] = Counter()
    for row in rows:
        references = expand_refdes(row["refdes"])
        if int(row["quantity"]) != len(references):
            raise AssertionError(f"quantity does not match refdes expression: {row['refdes']}")
        population = row["population"]
        if population not in {"POP", "DNP", "PCB_ONLY"}:
            raise AssertionError(f"invalid population state: {row['refdes']}={population}")
        populations[population] += len(references)
        for reference in references:
            if reference in bom_refs:
                raise AssertionError(f"duplicate BOM reference: {reference}")
            bom_refs[reference] = row

        for required in ("function", "manufacturer", "manufacturer_part_number", "footprint", "lifecycle_status", "notes"):
            if not row[required].strip():
                raise AssertionError(f"blank {required} field: {row['refdes']}")
        if row["lifecycle_checked"] != RELEASE_DATE:
            raise AssertionError(f"stale lifecycle review date: {row['refdes']}")
        if population in {"POP", "DNP"}:
            if row["manufacturer_part_number"] in {"N/A", "NONE"}:
                raise AssertionError(f"missing exact manufacturer part number: {row['refdes']}")
            if not row["source_url"].startswith("https://"):
                raise AssertionError(f"missing official HTTPS source: {row['refdes']}")

    if set(bom_refs) != set(board_footprints):
        missing = sorted(set(board_footprints) - set(bom_refs))
        extra = sorted(set(bom_refs) - set(board_footprints))
        raise AssertionError(f"BOM/board reference mismatch: missing={missing}, extra={extra}")
    if populations != Counter({"POP": 48, "PCB_ONLY": 8, "DNP": 1}):
        raise AssertionError(f"unexpected population totals: {dict(populations)}")

    for reference, footprint in board_footprints.items():
        row = bom_refs[reference]
        actual_footprint = str(footprint.GetFPID().GetLibItemName())
        if row["footprint"] != actual_footprint:
            raise AssertionError(
                f"footprint mismatch for {reference}: BOM={row['footprint']}, board={actual_footprint}"
            )
        expected_population = (
            "PCB_ONLY" if reference.startswith("TP")
            else "DNP" if reference == "U2"
            else "POP"
        )
        if row["population"] != expected_population:
            raise AssertionError(
                f"population mismatch for {reference}: {row['population']} != {expected_population}"
            )

    if not board_footprints["U2"].IsDNP():
        raise AssertionError("U2 must carry the native KiCad DNP attribute")
    for index in range(1, 9):
        footprint = board_footprints[f"TP{index}"]
        if not footprint.IsExcludedFromBOM() or not footprint.IsExcludedFromPosFiles():
            raise AssertionError(f"TP{index} is not excluded from assembly outputs")

    critical_parts = {
        "J1": "USB4105-GF-A-120",
        "J2": "TST-107-01-L-D",
        "U1": "FT2232HL-REEL",
        "U4": "SN74AXC8T245PWR",
        "U5": "SN74AXC2T245RSWR",
        "CCORE": "GRM188R61A335KE15D",
    }
    for reference, part_number in critical_parts.items():
        if bom_refs[reference]["manufacturer_part_number"] != part_number:
            raise AssertionError(f"critical part selection changed for {reference}")
    return populations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("board", type=Path)
    parser.add_argument("bom", type=Path)
    args = parser.parse_args()
    try:
        populations = audit_bom(args.board, args.bom)
    except (AssertionError, KeyError, OSError, ValueError) as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    print(
        "PASS production BOM: "
        f"{populations['POP']} fitted, {populations['DNP']} DNP, "
        f"{populations['PCB_ONLY']} PCB-only references"
    )
    print("PASS production BOM: exact critical MPNs, board footprints, sources, lifecycle review date")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
