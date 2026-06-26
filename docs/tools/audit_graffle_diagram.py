#!/usr/bin/env python3
"""Audit editable OmniGraffle diagrams for wasp1 drawing rules.

The audit is intentionally conservative and deterministic. It checks the saved
`.graffle` plist, not a screenshot, so it can run in normal CLI verification
flows before a final human OmniGraffle inspection.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import plistlib
import re
import sys


GRID_PT = 5.0
CLEARANCE_PT = 2.0 * GRID_PT
MANUAL_PREFIX = "manual-conn-"
ARROW_TOKEN = "-arrow-"


@dataclass(frozen=True)
class Rect:
    """Grid-space bounding box parsed from an OmniGraffle Bounds string."""

    name: str
    x: float
    y: float
    w: float
    h: float
    has_text: bool


@dataclass(frozen=True)
class Line:
    """Line object parsed from an OmniGraffle explicit point list."""

    name: str
    p0: tuple[float, float]
    p1: tuple[float, float]
    head_arrow: str | None
    tail_arrow: str | None


def _nums(text: str) -> list[float]:
    """Extract all numeric values from an OmniGraffle point/bounds string."""

    return [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", text)]


def _on_grid(value: float) -> bool:
    """Return true when value is exactly on the configured drawing grid."""

    return abs(value / GRID_PT - round(value / GRID_PT)) < 1e-6


def _rects_overlap(a: Rect, b: Rect) -> bool:
    """Return true when two shape bounds overlap."""

    return not (
        a.x + a.w <= b.x
        or b.x + b.w <= a.x
        or a.y + a.h <= b.y
        or b.y + b.h <= a.y
    )


def _expanded(rect: Rect, margin: float) -> Rect:
    """Return a rectangle expanded equally on all sides."""

    return Rect(
        rect.name,
        rect.x - margin,
        rect.y - margin,
        rect.w + 2.0 * margin,
        rect.h + 2.0 * margin,
        rect.has_text,
    )


def _point_on_rect_boundary(point: tuple[float, float], rect: Rect) -> bool:
    """Return true when a point lies exactly on a rectangle boundary."""

    x, y = point
    on_left = x == rect.x and rect.y <= y <= rect.y + rect.h
    on_right = x == rect.x + rect.w and rect.y <= y <= rect.y + rect.h
    on_top = y == rect.y and rect.x <= x <= rect.x + rect.w
    on_bottom = y == rect.y + rect.h and rect.x <= x <= rect.x + rect.w
    return on_left or on_right or on_top or on_bottom


def _point_inside_rect(point: tuple[float, float], rect: Rect) -> bool:
    """Return true when a point is inside or on a rectangle."""

    x, y = point
    return rect.x <= x <= rect.x + rect.w and rect.y <= y <= rect.y + rect.h


def _line_axis(line: Line) -> str:
    """Return h/v/d for horizontal, vertical, or diagonal line."""

    if line.p0[1] == line.p1[1]:
        return "h"
    if line.p0[0] == line.p1[0]:
        return "v"
    return "d"


def _segment_inside_axis_rect_interval(line: Line, rect: Rect) -> float:
    """Return overlap length between a horizontal/vertical segment and a rect."""

    axis = _line_axis(line)
    x0, y0 = line.p0
    x1, y1 = line.p1

    if axis == "h":
        if not (rect.y <= y0 <= rect.y + rect.h):
            return 0.0
        lo, hi = sorted((x0, x1))
        return max(0.0, min(hi, rect.x + rect.w) - max(lo, rect.x))

    if axis == "v":
        if not (rect.x <= x0 <= rect.x + rect.w):
            return 0.0
        lo, hi = sorted((y0, y1))
        return max(0.0, min(hi, rect.y + rect.h) - max(lo, rect.y))

    return 0.0


def _segment_length(line: Line) -> float:
    """Return Manhattan length for axis lines or max delta for arrow diagonals."""

    return max(abs(line.p0[0] - line.p1[0]), abs(line.p0[1] - line.p1[1]))


def _line_is_allowed_shape_connection(line: Line, rect: Rect) -> bool:
    """Allow only the short clearance corridor at a real shape connection point."""

    axis = _line_axis(line)
    if axis == "d":
        return False

    for endpoint, other in ((line.p0, line.p1), (line.p1, line.p0)):
        if not _point_on_rect_boundary(endpoint, rect):
            continue

        ex, ey = endpoint
        ox, oy = other
        # The segment must leave the shape outward, not run along a shape edge
        # or travel into/through the shape body.
        if axis == "h":
            if ey == rect.y or ey == rect.y + rect.h:
                return False
            if ex == rect.x and ox < ex:
                return True
            if ex == rect.x + rect.w and ox > ex:
                return True
        if axis == "v":
            if ex == rect.x or ex == rect.x + rect.w:
                return False
            if ey == rect.y and oy < ey:
                return True
            if ey == rect.y + rect.h and oy > ey:
                return True

    return False


def _line_hits_rect(line: Line, rect: Rect, margin: float = 1.0) -> bool:
    """Detect horizontal/vertical line segments passing through a label box."""

    x = rect.x - margin
    y = rect.y - margin
    w = rect.w + 2.0 * margin
    h = rect.h + 2.0 * margin
    x0, y0 = line.p0
    x1, y1 = line.p1

    if y0 == y1:
        lo, hi = sorted((x0, x1))
        return y <= y0 <= y + h and max(lo, x) < min(hi, x + w)

    if x0 == x1:
        lo, hi = sorted((y0, y1))
        return x <= x0 <= x + w and max(lo, y) < min(hi, y + h)

    return False


def _route_name(line_name: str) -> str:
    """Return the route prefix used by generated line/arrow objects."""

    name = line_name
    if name.startswith(f"{MANUAL_PREFIX}line-"):
        name = name[len(f"{MANUAL_PREFIX}line-") :]
    for suffix in ("-arrow-a", "-arrow-b"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return re.sub(r"-s\d+$", "", name)


def _segments_intersect(a: Line, b: Line) -> bool:
    """Return true for non-endpoint overlap/crossing between axis segments."""

    a_axis = _line_axis(a)
    b_axis = _line_axis(b)
    if "d" in (a_axis, b_axis):
        return False

    ax0, ay0 = a.p0
    ax1, ay1 = a.p1
    bx0, by0 = b.p0
    bx1, by1 = b.p1

    if a_axis == "h" and b_axis == "v":
        alo, ahi = sorted((ax0, ax1))
        blo, bhi = sorted((by0, by1))
        point = (bx0, ay0)
        return alo < bx0 < ahi and blo < ay0 < bhi and point not in (a.p0, a.p1, b.p0, b.p1)

    if a_axis == "v" and b_axis == "h":
        return _segments_intersect(b, a)

    if a_axis == b_axis == "h" and ay0 == by0:
        alo, ahi = sorted((ax0, ax1))
        blo, bhi = sorted((bx0, bx1))
        return max(alo, blo) < min(ahi, bhi)

    if a_axis == b_axis == "v" and ax0 == bx0:
        alo, ahi = sorted((ay0, ay1))
        blo, bhi = sorted((by0, by1))
        return max(alo, blo) < min(ahi, bhi)

    return False


def _allowed_line_join(a: Line, b: Line) -> bool:
    """Allow intended joins within one route and at a V-arrow tip."""

    shared = set((a.p0, a.p1)) & set((b.p0, b.p1))
    if not shared:
        return False
    if _route_name(a.name) == _route_name(b.name):
        return True
    if ARROW_TOKEN in a.name or ARROW_TOKEN in b.name:
        return True
    return False


def audit(path: Path) -> list[str]:
    """Return a list of rule violations found in one OmniGraffle file."""

    issues: list[str] = []

    with path.open("rb") as stream:
        data = plistlib.load(stream)

    canvas_nums = _nums(str(data.get("CanvasSize", "")))
    canvas = tuple(canvas_nums[:2]) if len(canvas_nums) >= 2 else None

    if data.get("HPages") != 1 or data.get("VPages") != 1:
        issues.append(f"page count is HPages={data.get('HPages')} VPages={data.get('VPages')}, expected 1x1")

    rects: list[Rect] = []
    lines: list[Line] = []

    for graphic in data.get("GraphicsList", []):
        name = str(graphic.get("Name", f"id-{graphic.get('ID', '?')}"))
        cls = graphic.get("Class")

        if cls == "ShapedGraphic":
            shape = graphic.get("Shape")
            if shape == "Triangle":
                issues.append(f"{name}: Triangle shape is not allowed for arrowheads")

            bounds = _nums(str(graphic.get("Bounds", "")))
            if len(bounds) == 4:
                x, y, w, h = bounds
                for value in bounds:
                    if not _on_grid(value):
                        issues.append(f"{name}: bounds {graphic.get('Bounds')} are not on the {GRID_PT:g}pt grid")
                        break
                if canvas is not None and (x < 0 or y < 0 or x + w > canvas[0] or y + h > canvas[1]):
                    issues.append(f"{name}: bounds {graphic.get('Bounds')} exceed canvas {data.get('CanvasSize')}")
                rects.append(Rect(name, x, y, w, h, bool(graphic.get("Text", {}).get("Text"))))

        elif cls == "LineGraphic":
            points = []
            for point_text in graphic.get("Points", []):
                point_nums = _nums(str(point_text))
                if len(point_nums) == 2:
                    x, y = point_nums
                    points.append((x, y))
                    if not _on_grid(x) or not _on_grid(y):
                        issues.append(f"{name}: point {point_text} is not on the {GRID_PT:g}pt grid")
                    if canvas is not None and (x < 0 or y < 0 or x > canvas[0] or y > canvas[1]):
                        issues.append(f"{name}: point {point_text} exceeds canvas {data.get('CanvasSize')}")

            stroke = graphic.get("Style", {}).get("stroke", {})
            head_arrow = stroke.get("HeadArrow")
            tail_arrow = stroke.get("TailArrow")
            if head_arrow not in (None, "0") or tail_arrow not in (None, "0"):
                issues.append(f"{name}: connector arrowheads are not allowed")

            if len(points) != 2:
                issues.append(f"{name}: expected exactly two explicit points, got {len(points)}")
                continue

            line = Line(name, points[0], points[1], head_arrow, tail_arrow)
            lines.append(line)

            x0, y0 = line.p0
            x1, y1 = line.p1
            if ARROW_TOKEN not in name and x0 != x1 and y0 != y1:
                issues.append(f"{name}: non-arrow line segment must be horizontal or vertical")

    for idx, lhs in enumerate(rects):
        for rhs in rects[idx + 1 :]:
            if _rects_overlap(lhs, rhs):
                issues.append(f"{lhs.name}: shape bounds overlap {rhs.name}")

    text_rects = [rect for rect in rects if rect.has_text]
    label_rects = [rect for rect in text_rects if rect.name.startswith(f"{MANUAL_PREFIX}label-")]
    for line in lines:
        if ARROW_TOKEN in line.name:
            continue
        for label in label_rects:
            if _line_hits_rect(line, label):
                issues.append(f"{line.name}: line passes through label {label.name}")

    for line in lines:
        if ARROW_TOKEN in line.name:
            continue
        for rect in rects:
            expanded_rect = _expanded(rect, CLEARANCE_PT - 1e-6)
            if _segment_inside_axis_rect_interval(line, expanded_rect) <= 0.0:
                continue
            if _line_is_allowed_shape_connection(line, rect):
                continue
            issues.append(
                f"{line.name}: line overlaps or is within {CLEARANCE_PT:g}pt of shape {rect.name}"
            )

    for idx, lhs in enumerate(lines):
        for rhs in lines[idx + 1 :]:
            if _allowed_line_join(lhs, rhs):
                continue
            if _segments_intersect(lhs, rhs):
                issues.append(f"{lhs.name}: line overlaps/crosses {rhs.name}")

    body_by_route: dict[str, list[Line]] = {}
    arrow_by_route: dict[str, list[Line]] = {}
    for line in lines:
        route = _route_name(line.name)
        if ARROW_TOKEN in line.name:
            arrow_by_route.setdefault(route, []).append(line)
        else:
            body_by_route.setdefault(route, []).append(line)

    for route, arrow_lines in arrow_by_route.items():
        if len(arrow_lines) != 2:
            issues.append(f"{route}: expected exactly two V-arrow lines, got {len(arrow_lines)}")
            continue

        for arrow_line in arrow_lines:
            if _line_axis(arrow_line) != "d":
                issues.append(f"{arrow_line.name}: V-arrow segment must be diagonal")
            if _segment_length(arrow_line) > 10.0:
                issues.append(f"{arrow_line.name}: V-arrow segment is longer than 10pt")

        endpoint_counts: dict[tuple[float, float], int] = {}
        for arrow_line in arrow_lines:
            endpoint_counts[arrow_line.p0] = endpoint_counts.get(arrow_line.p0, 0) + 1
            endpoint_counts[arrow_line.p1] = endpoint_counts.get(arrow_line.p1, 0) + 1
        tips = [point for point, count in endpoint_counts.items() if count == 2]
        if len(tips) != 1:
            issues.append(f"{route}: V-arrow lines must share exactly one tip")
            continue
        tip = tips[0]

        body_endpoints = {
            endpoint
            for body_line in body_by_route.get(route, [])
            for endpoint in (body_line.p0, body_line.p1)
        }
        if tip not in body_endpoints:
            issues.append(f"{route}: V-arrow tip {tip} does not match any body line endpoint")

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path, help="OmniGraffle .graffle file(s) to audit")
    args = parser.parse_args()

    failed = False
    for path in args.paths:
        issues = audit(path)
        if issues:
            failed = True
            print(f"{path}: FAIL")
            for issue in issues:
                print(f"  - {issue}")
        else:
            print(f"{path}: PASS")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
