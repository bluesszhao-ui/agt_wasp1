#!/usr/bin/env python3
"""Independently audit generated Rev A PCB manufacturing outputs."""

from __future__ import annotations

from collections import Counter, defaultdict
from pathlib import Path
import argparse
import csv
import json
import math
import re
import sys


BOARD = "wasp1_ft2232h_debugger_revA"
BOARD_BOUNDS = (15.0, -85.0, 125.0, -20.0)
GERBER_LAYERS = {
    "F_Cu": ("Copper,L1,Top", "Positive"),
    "In1_Cu": ("Copper,L2,Inr", "Positive"),
    "In2_Cu": ("Copper,L3,Inr", "Positive"),
    "B_Cu": ("Copper,L4,Bot", "Positive"),
    "F_Mask": ("Soldermask,Top", "Negative"),
    "B_Mask": ("Soldermask,Bot", "Negative"),
    "F_Silkscreen": ("Legend,Top", "Positive"),
    "B_Silkscreen": ("Legend,Bot", "Positive"),
    "Edge_Cuts": ("Profile,NP", None),
}
GERBER_COORD = re.compile(r"^X(-?\d+)Y(-?\d+)(D0[123])\*$")
DRILL_COORD = re.compile(r"^(?:G0[01])?X(-?\d+(?:\.\d+)?)Y(-?\d+(?:\.\d+)?)$")


def require_file(path: Path, minimum_size: int = 1) -> Path:
    """Require one generated file with a useful nonzero payload."""
    if not path.is_file():
        raise AssertionError(f"missing manufacturing output: {path}")
    if path.stat().st_size < minimum_size:
        raise AssertionError(f"manufacturing output is too small: {path}")
    return path


def gerber_points(content: str) -> list[tuple[float, float, str]]:
    """Decode absolute 4.6-metric coordinates from Gerber data records."""
    points = []
    for line in content.splitlines():
        match = GERBER_COORD.match(line)
        if match:
            points.append((int(match[1]) / 1_000_000, int(match[2]) / 1_000_000, match[3]))
    return points


def within_board(point: tuple[float, float], tolerance: float = 0.001) -> bool:
    """Return true when one manufacturing coordinate lies on or inside the outline."""
    x_min, y_min, x_max, y_max = BOARD_BOUNDS
    x, y = point
    return (
        x_min - tolerance <= x <= x_max + tolerance
        and y_min - tolerance <= y <= y_max + tolerance
    )


def audit_edge_profile(points: list[tuple[float, float, str]]) -> None:
    """Require a closed four-edge 110 mm by 65 mm rectangular profile."""
    current: tuple[float, float] | None = None
    edges: list[tuple[tuple[float, float], tuple[float, float]]] = []
    for x, y, operation in points:
        point = (x, y)
        if operation == "D02":
            current = point
        elif operation == "D01":
            if current is None:
                raise AssertionError("edge profile draws before selecting a start point")
            edges.append((current, point))
            current = point
    if len(edges) != 4:
        raise AssertionError(f"expected four board-profile edges, got {len(edges)}")

    vertices = Counter(vertex for edge in edges for vertex in edge)
    if set(vertices.values()) != {2} or len(vertices) != 4:
        raise AssertionError("board profile is not a closed four-vertex loop")
    xs = [point[0] for point in vertices]
    ys = [point[1] for point in vertices]
    if (min(xs), min(ys), max(xs), max(ys)) != BOARD_BOUNDS:
        raise AssertionError("board-profile bounds are not 110 mm by 65 mm at the release origin")
    perimeter = sum(math.dist(start, end) for start, end in edges)
    if not math.isclose(perimeter, 350.0, abs_tol=1e-6):
        raise AssertionError(f"unexpected board-profile perimeter: {perimeter:.6f} mm")


def audit_gerbers(root: Path) -> None:
    """Check X2 metadata, coordinates, profile closure, and the job manifest."""
    gerber_dir = root / "gerber"
    for layer, (file_function, polarity) in GERBER_LAYERS.items():
        path = require_file(gerber_dir / f"{BOARD}-{layer}.gbr", 200)
        content = path.read_text(encoding="ascii")
        required = (
            f"%TF.FileFunction,{file_function}*%",
            "%TF.SameCoordinates,Original*%",
            "%FSLAX46Y46*%",
            "%MOMM*%",
        )
        if any(item not in content for item in required) or not content.rstrip().endswith("M02*"):
            raise AssertionError(f"invalid Gerber X2 framing or metadata: {path}")
        if polarity is not None and f"%TF.FilePolarity,{polarity}*%" not in content:
            raise AssertionError(f"unexpected Gerber polarity: {path}")
        points = gerber_points(content)
        if not points:
            raise AssertionError(f"Gerber contains no absolute coordinates: {path}")
        outside = [(x, y) for x, y, _ in points if not within_board((x, y))]
        if outside:
            raise AssertionError(f"Gerber coordinates escape the board profile: {path}: {outside[:3]}")
        if layer == "Edge_Cuts":
            audit_edge_profile(points)

    job = require_file(gerber_dir / f"{BOARD}-job.gbrjob", 500)
    job_data = json.loads(job.read_text(encoding="utf-8"))
    entries = job_data.get("FilesAttributes", [])
    if len(entries) != len(GERBER_LAYERS):
        raise AssertionError("Gerber job manifest does not list all nine layers")
    listed = {Path(entry["Path"]).name for entry in entries}
    expected = {f"{BOARD}-{layer}.gbr" for layer in GERBER_LAYERS}
    if listed != expected:
        raise AssertionError("Gerber job manifest filenames differ from the release layer set")


def parse_drill(path: Path) -> tuple[dict[int, float], Counter[int], list[float], list[tuple[float, float]]]:
    """Return Excellon tools, round-hit counts, routed-slot lengths, and coordinates."""
    tools: dict[int, float] = {}
    hits: Counter[int] = Counter()
    slots: list[float] = []
    points: list[tuple[float, float]] = []
    active_tool: int | None = None
    route_start: tuple[float, float] | None = None
    routing = False
    for line in path.read_text(encoding="ascii").splitlines():
        definition = re.match(r"^T(\d+)C(\d+(?:\.\d+)?)$", line)
        selection = re.match(r"^T(\d+)$", line)
        coordinate = DRILL_COORD.match(line)
        if definition:
            tools[int(definition[1])] = float(definition[2])
        elif selection:
            active_tool = int(selection[1])
        elif line == "M15":
            routing = True
        elif line == "M16":
            routing = False
            route_start = None
        elif coordinate:
            point = (float(coordinate[1]), float(coordinate[2]))
            points.append(point)
            if line.startswith("G00"):
                route_start = point
            elif line.startswith("G01"):
                if not routing or route_start is None:
                    raise AssertionError(f"malformed routed slot in {path}")
                slots.append(math.dist(route_start, point))
                route_start = point
            else:
                if active_tool is None:
                    raise AssertionError(f"drill hit has no selected tool in {path}")
                hits[active_tool] += 1
    return tools, hits, slots, points


def audit_drills(root: Path) -> None:
    """Check plated/non-plated tools, hit counts, slots, bounds, maps, and report."""
    drill_dir = root / "drill"
    expected = {
        "PTH": ({1: 0.3, 2: 0.4, 3: 0.6, 4: 1.0}, Counter({1: 65, 2: 7, 4: 14})),
        "NPTH": ({1: 0.65}, Counter({1: 2})),
    }
    for kind, (expected_tools, expected_hits) in expected.items():
        drill = require_file(drill_dir / f"{BOARD}-{kind}.drl", 200)
        content = drill.read_text(encoding="ascii")
        if not content.startswith("M48") or "METRIC" not in content or not content.rstrip().endswith("M30"):
            raise AssertionError(f"invalid Excellon framing: {drill}")
        tools, hits, slots, points = parse_drill(drill)
        if tools != expected_tools or hits != expected_hits:
            raise AssertionError(
                f"unexpected {kind} drill tools/hits: tools={tools}, hits={dict(hits)}"
            )
        if any(not within_board(point) for point in points):
            raise AssertionError(f"{kind} drill coordinate lies outside the board profile")
        if kind == "PTH" and sorted(round(length, 3) for length in slots) != [0.8, 0.8, 1.1, 1.1]:
            raise AssertionError(f"unexpected USB-C plated-slot geometry: {slots}")
        if kind == "NPTH" and slots:
            raise AssertionError("NPTH release unexpectedly contains routed slots")
        require_file(drill_dir / f"{BOARD}-{kind}-drl_map.svg", 1000)

    report = require_file(root / f"{BOARD}_drill_report.txt", 500).read_text(encoding="utf-8")
    for item in ("Total plated holes count 90", "Total unplated holes count 2"):
        if item not in report:
            raise AssertionError(f"drill report is missing {item!r}")


def audit_positions(root: Path) -> None:
    """Require only fitted physical components in the pick-and-place output."""
    path = require_file(root / f"{BOARD}_positions.csv", 1000)
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    references = [row["Ref"] for row in rows]
    if len(rows) != 48 or len(set(references)) != 48:
        raise AssertionError(f"expected 48 unique fitted position rows, got {len(rows)}")
    excluded = {"U2", *(f"TP{index}" for index in range(1, 9))}
    unexpected = excluded.intersection(references)
    if unexpected:
        raise AssertionError(f"DNP/PCB-only references appear in positions: {sorted(unexpected)}")
    if any(row["Side"] != "top" for row in rows):
        raise AssertionError("Rev A position output must contain top-side components only")
    for row in rows:
        if not within_board((float(row["PosX"]), float(row["PosY"]))):
            raise AssertionError(f"position lies outside board profile: {row['Ref']}")
    if not {"J1", "J2", "U1", "U4", "U5", "U6"}.issubset(references):
        raise AssertionError("position output is missing a critical component")


def audit_supporting_outputs(root: Path) -> None:
    """Check electrical-test data, board statistics, and assembly drawings."""
    ipc = require_file(root / f"{BOARD}.ipc", 1000).read_text(encoding="ascii")
    if not ipc.startswith("P  CODE 00") or "P  UNITS CUST 0" not in ipc or "317USB_VBUS" not in ipc:
        raise AssertionError("IPC-D-356 output is missing its identification records")

    stats_path = require_file(root / f"{BOARD}_board_stats.json", 1000)
    stats = json.loads(stats_path.read_text(encoding="utf-8"))
    expected_board = {
        "width": "110.0000 mm",
        "height": "65.0000 mm",
        "area": "7150.00 mm²",
        "min_track_clearance": "0.1500 mm",
        "min_track_width": "0.2000 mm",
        "min_drill_diameter": "0.3000 mm",
        # KiCad includes the two 0.01 mm solder-mask layers in this statistic;
        # the source-board finished substrate/copper thickness remains 1.6 mm.
        "board_thickness": "1.6200 mm",
    }
    if any(stats["board"].get(key) != value for key, value in expected_board.items()):
        raise AssertionError("board statistics differ from the released geometry/technology")
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
    except (AssertionError, KeyError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    print("PASS Gerber X2: 9 layers, common 4.6 metric coordinates, closed 110x65 mm profile")
    print("PASS drills: 86 round PTH, 4 plated slots, 2 NPTH, all coordinates in bounds")
    print("PASS assembly: 48 fitted positions; U2 and PCB-only TP1-TP8 excluded")
    print("PASS support: IPC-D-356, board statistics, top/bottom assembly PDFs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
