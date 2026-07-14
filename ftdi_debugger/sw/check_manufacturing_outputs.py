#!/usr/bin/env python3
"""Audit generated Rev A PCB manufacturing outputs."""

from __future__ import annotations

from pathlib import Path
import argparse
import csv
import json
import sys


BOARD = "wasp1_ft2232h_debugger_revA"
GERBER_LAYERS = (
    "F_Cu",
    "In1_Cu",
    "In2_Cu",
    "B_Cu",
    "F_Mask",
    "B_Mask",
    "F_Silkscreen",
    "B_Silkscreen",
    "Edge_Cuts",
)


def require_file(path: Path, minimum_size: int = 1) -> Path:
    """Require one generated file with a useful nonzero payload."""
    if not path.is_file():
        raise AssertionError(f"missing manufacturing output: {path}")
    if path.stat().st_size < minimum_size:
        raise AssertionError(f"manufacturing output is too small: {path}")
    return path


def audit_gerbers(root: Path) -> None:
    """Check every fabrication layer and the Gerber job manifest."""
    gerber_dir = root / "gerber"
    for layer in GERBER_LAYERS:
        path = require_file(gerber_dir / f"{BOARD}-{layer}.gbr", 200)
        content = path.read_text(encoding="ascii")
        if "%TF.FileFunction," not in content or not content.rstrip().endswith("M02*"):
            raise AssertionError(f"invalid Gerber X2 framing: {path}")
    job = require_file(gerber_dir / f"{BOARD}-job.gbrjob", 500)
    job_data = json.loads(job.read_text(encoding="utf-8"))
    if len(job_data.get("FilesAttributes", [])) != len(GERBER_LAYERS):
        raise AssertionError("Gerber job manifest does not list all nine layers")


def audit_drills(root: Path) -> None:
    """Check plated/non-plated drill streams, maps, and hole-count report."""
    drill_dir = root / "drill"
    for kind in ("PTH", "NPTH"):
        drill = require_file(drill_dir / f"{BOARD}-{kind}.drl", 200)
        content = drill.read_text(encoding="ascii")
        if not content.startswith("M48") or not content.rstrip().endswith("M30"):
            raise AssertionError(f"invalid Excellon framing: {drill}")
        require_file(drill_dir / f"{BOARD}-{kind}-drl_map.svg", 1000)
    report = require_file(root / f"{BOARD}_drill_report.txt", 500).read_text(
        encoding="utf-8"
    )
    for expected in ("Total plated holes count 90", "Total unplated holes count 2"):
        if expected not in report:
            raise AssertionError(f"drill report is missing {expected!r}")


def audit_positions(root: Path) -> None:
    """Require all populated references and ensure the DNP EEPROM is absent."""
    path = require_file(root / f"{BOARD}_positions.csv", 1000)
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    references = {row["Ref"] for row in rows}
    if len(rows) != 56:
        raise AssertionError(f"expected 56 populated position rows, got {len(rows)}")
    if "U2" in references:
        raise AssertionError("DNP EEPROM U2 must not appear in position output")
    if not {"J1", "J2", "U1", "U4", "U5", "U6"}.issubset(references):
        raise AssertionError("position output is missing a critical component")


def audit_supporting_outputs(root: Path) -> None:
    """Check electrical test data, board statistics, and assembly drawings."""
    ipc = require_file(root / f"{BOARD}.ipc", 1000).read_text(encoding="ascii")
    if not ipc.startswith("P  CODE 00") or "P  UNITS CUST 0" not in ipc or "317USB_VBUS" not in ipc:
        raise AssertionError("IPC-D-356 output is missing its identification records")

    stats_path = require_file(root / f"{BOARD}_board_stats.json", 1000)
    stats = json.loads(stats_path.read_text(encoding="utf-8"))
    if stats["board"]["width"] != "110.0000 mm" or stats["board"]["height"] != "65.0000 mm":
        raise AssertionError("board statistics contain an unexpected outline size")
    if stats["components"]["total"]["total"] != 57:
        raise AssertionError("board statistics contain an unexpected footprint count")

    for side in ("top", "bottom"):
        pdf = require_file(root / f"{BOARD}_{side}_assembly.pdf", 10000)
        if pdf.read_bytes()[:5] != b"%PDF-":
            raise AssertionError(f"assembly drawing is not a PDF: {pdf}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    try:
        audit_gerbers(args.directory)
        audit_drills(args.directory)
        audit_positions(args.directory)
        audit_supporting_outputs(args.directory)
    except (AssertionError, KeyError, OSError, json.JSONDecodeError) as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    print("PASS manufacturing outputs: 9 Gerbers, PTH/NPTH drills, 56 placements")
    print("PASS manufacturing support: IPC-D-356, board stats, top/bottom assembly PDFs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
