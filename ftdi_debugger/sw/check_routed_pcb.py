#!/usr/bin/env python3
"""Audit the committed routed PCB and its final KiCad DRC report."""

from __future__ import annotations

from collections import Counter, defaultdict
from pathlib import Path
import argparse
import re
import sys

import pcbnew


MAX_USB_SKEW_MM = 0.50


def audit_report(report_path: Path) -> Counter[str]:
    """Require a clean report apart from the two reviewed local footprints."""
    report = report_path.read_text(encoding="utf-8")
    categories = Counter(re.findall(r"^\[([^]]+)\]:", report, flags=re.MULTILINE))
    expected = Counter({"lib_footprint_mismatch": 2})
    if categories != expected:
        raise AssertionError(
            f"DRC categories differ: expected {dict(expected)}, observed {dict(categories)}"
        )
    for summary in (
        "** Found 0 unconnected pads **",
        "** Found 0 Footprint errors **",
    ):
        if summary not in report:
            raise AssertionError(f"DRC report is missing summary {summary!r}")
    for reference in ("J1", "J2"):
        if not re.search(rf"(?:footprint|封装) {reference}\b", report):
            raise AssertionError(f"DRC report is missing reviewed warning for {reference}")
    return categories


def routed_lengths(board: pcbnew.BOARD) -> dict[str, float]:
    """Return routed copper length per net, excluding through-via barrel length."""
    lengths: defaultdict[str, float] = defaultdict(float)
    for item in board.GetTracks():
        if not isinstance(item, pcbnew.PCB_VIA):
            lengths[item.GetNetname()] += pcbnew.ToMM(item.GetLength())
    return dict(lengths)


def audit_board(board_path: Path) -> dict[str, float | int]:
    """Check routing scale, constraints, plane, orientation, and USB matching."""
    board = pcbnew.LoadBoard(str(board_path.resolve()))
    if board.GetCopperLayerCount() != 4:
        raise AssertionError(f"expected four copper layers, got {board.GetCopperLayerCount()}")
    if len(board.GetFootprints()) != 57:
        raise AssertionError(f"expected 57 footprints, got {len(board.GetFootprints())}")

    tracks = list(board.GetTracks())
    segment_count = sum(not isinstance(item, pcbnew.PCB_VIA) for item in tracks)
    via_count = sum(isinstance(item, pcbnew.PCB_VIA) for item in tracks)
    if segment_count < 600 or via_count < 50:
        raise AssertionError(
            f"board does not look fully routed: {segment_count} segments, {via_count} vias"
        )

    widths = {
        round(pcbnew.ToMM(item.GetWidth()), 6)
        for item in tracks
        if not isinstance(item, pcbnew.PCB_VIA)
    }
    expected_widths = {0.20, 0.25, 0.50}
    if widths != expected_widths:
        raise AssertionError(f"unexpected track-width set: {sorted(widths)}")

    ground_zones = [
        zone
        for zone in board.Zones()
        if zone.GetZoneName() == "GND_PLANE_IN1"
    ]
    if len(ground_zones) != 1:
        raise AssertionError(f"expected one GND_PLANE_IN1 zone, got {len(ground_zones)}")
    ground_zone = ground_zones[0]
    if ground_zone.GetNetname() != "GND":
        raise AssertionError("GND_PLANE_IN1 is not assigned to GND")
    if board.GetLayerName(ground_zone.GetLayer()) != "In1.Cu":
        raise AssertionError("GND_PLANE_IN1 is not on In1.Cu")
    if not ground_zone.IsFilled():
        raise AssertionError("GND_PLANE_IN1 has not been filled")

    j1 = board.FindFootprintByReference("J1")
    if j1 is None or abs(j1.GetOrientationDegrees() + 90.0) > 0.01:
        observed = None if j1 is None else j1.GetOrientationDegrees()
        raise AssertionError(f"USB-C J1 orientation is incorrect: {observed}")

    lengths = routed_lengths(board)
    required_usb_nets = ("USB_DP_CONN", "USB_DM_CONN", "USB_DP", "USB_DM")
    missing = [net for net in required_usb_nets if net not in lengths]
    if missing:
        raise AssertionError(f"USB routed-length data is missing: {', '.join(missing)}")
    pre_esd_skew = abs(lengths["USB_DP_CONN"] - lengths["USB_DM_CONN"])
    post_esd_skew = abs(lengths["USB_DP"] - lengths["USB_DM"])
    if pre_esd_skew > MAX_USB_SKEW_MM or post_esd_skew > MAX_USB_SKEW_MM:
        raise AssertionError(
            "USB length matching failed: "
            f"pre-ESD {pre_esd_skew:.6f} mm, post-ESD {post_esd_skew:.6f} mm"
        )

    return {
        "segments": segment_count,
        "vias": via_count,
        "usb_dp_conn_mm": lengths["USB_DP_CONN"],
        "usb_dm_conn_mm": lengths["USB_DM_CONN"],
        "pre_esd_skew_mm": pre_esd_skew,
        "usb_dp_mm": lengths["USB_DP"],
        "usb_dm_mm": lengths["USB_DM"],
        "post_esd_skew_mm": post_esd_skew,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("board", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()

    try:
        categories = audit_report(args.report)
        metrics = audit_board(args.board)
    except (AssertionError, OSError) as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1

    print(
        "PASS routed PCB: "
        f"{metrics['segments']} segments, {metrics['vias']} vias, "
        f"DRC={dict(categories)}"
    )
    print(
        "PASS USB pre-ESD: "
        f"D+={metrics['usb_dp_conn_mm']:.6f} mm, "
        f"D-={metrics['usb_dm_conn_mm']:.6f} mm, "
        f"skew={metrics['pre_esd_skew_mm']:.6f} mm"
    )
    print(
        "PASS USB post-ESD: "
        f"D+={metrics['usb_dp_mm']:.6f} mm, "
        f"D-={metrics['usb_dm_mm']:.6f} mm, "
        f"skew={metrics['post_esd_skew_mm']:.6f} mm"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
