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


def mm_point(vector: pcbnew.VECTOR2I) -> tuple[float, float]:
    """Convert one KiCad internal coordinate to rounded millimetres."""
    return (round(pcbnew.ToMM(vector.x), 6), round(pcbnew.ToMM(vector.y), 6))


def audit_release_geometry(board: pcbnew.BOARD) -> None:
    """Check board technology and the two release-critical local footprints."""
    thickness = pcbnew.ToMM(board.GetDesignSettings().GetBoardThickness())
    if not abs(thickness - 1.6) < 1e-6:
        raise AssertionError(f"source-board finished thickness is not 1.6 mm: {thickness}")

    edge_segments = []
    for item in board.GetDrawings():
        if str(board.GetLayerName(item.GetLayer())) == "Edge.Cuts":
            if not isinstance(item, pcbnew.PCB_SHAPE) or item.GetShape() != pcbnew.SHAPE_T_SEGMENT:
                raise AssertionError("Rev A board outline must contain only straight segments")
            edge_segments.append((mm_point(item.GetStart()), mm_point(item.GetEnd())))
    expected_edges = {
        ((15.0, 20.0), (125.0, 20.0)),
        ((125.0, 20.0), (125.0, 85.0)),
        ((125.0, 85.0), (15.0, 85.0)),
        ((15.0, 85.0), (15.0, 20.0)),
    }
    if set(edge_segments) != expected_edges:
        raise AssertionError(f"unexpected source-board outline: {edge_segments}")

    j1 = board.FindFootprintByReference("J1")
    if j1 is None:
        raise AssertionError("USB-C footprint J1 is missing")
    if str(j1.GetFPID().GetLibItemName()) != "USB_C_Receptacle_GCT_USB4105-xx-A_16P_TopMnt_Horizontal":
        raise AssertionError("J1 is not the reviewed GCT USB4105 footprint")
    if mm_point(j1.GetPosition()) != (20.0, 50.0) or abs(j1.GetOrientationDegrees() + 90.0) > 0.01:
        raise AssertionError("USB-C J1 position/orientation differs from the reviewed release")
    j1_pads = list(j1.Pads())
    pad_numbers = Counter(str(pad.GetNumber()) for pad in j1_pads)
    expected_numbers = Counter({
        "": 2, "SH": 4,
        "A1": 1, "A4": 1, "A5": 1, "A6": 1, "A7": 1, "A8": 1,
        "A9": 1, "A12": 1, "B1": 1, "B4": 1, "B5": 1, "B6": 1,
        "B7": 1, "B8": 1, "B9": 1, "B12": 1,
    })
    if pad_numbers != expected_numbers:
        raise AssertionError(f"J1 USB-C pad map differs: {dict(pad_numbers)}")
    critical_usb = {
        "A6": (23.68, 49.75), "A7": (23.68, 50.25),
        "B6": (23.68, 50.75), "B7": (23.68, 49.25),
    }
    observed_usb = {
        str(pad.GetNumber()): mm_point(pad.GetPosition())
        for pad in j1_pads if str(pad.GetNumber()) in critical_usb
    }
    if observed_usb != critical_usb:
        raise AssertionError(f"J1 USB D+/D- pad placement differs: {observed_usb}")
    slot_drills = sorted(
        (round(pcbnew.ToMM(pad.GetDrillSize().x), 3), round(pcbnew.ToMM(pad.GetDrillSize().y), 3))
        for pad in j1_pads if str(pad.GetNumber()) == "SH"
    )
    if slot_drills != [(0.6, 1.4), (0.6, 1.4), (0.6, 1.7), (0.6, 1.7)]:
        raise AssertionError(f"J1 shell-slot geometry differs: {slot_drills}")

    j2 = board.FindFootprintByReference("J2")
    if j2 is None:
        raise AssertionError("target connector J2 is missing")
    if str(j2.GetFPID().GetLibItemName()) != "IDC-Header_2x07_P2.54mm_Vertical":
        raise AssertionError("J2 is not the reviewed 2x7 IDC footprint")
    if mm_point(j2.GetPosition()) != (117.0, 50.0) or abs(j2.GetOrientationDegrees()) > 0.01:
        raise AssertionError("target connector J2 position/orientation differs")
    j2_pads = {int(pad.GetNumber()): pad for pad in j2.Pads()}
    if set(j2_pads) != set(range(1, 15)):
        raise AssertionError("J2 must contain pins 1 through 14 exactly once")
    for number, pad in j2_pads.items():
        row = (number - 1) // 2
        column = (number - 1) % 2
        expected = (117.0 + column * 2.54, 50.0 + row * 2.54)
        drill = tuple(round(pcbnew.ToMM(value), 3) for value in (pad.GetDrillSize().x, pad.GetDrillSize().y))
        if mm_point(pad.GetPosition()) != expected or drill != (1.0, 1.0):
            raise AssertionError(f"J2 pin {number} geometry differs from the 2.54 mm grid")

    for index in range(1, 9):
        test_pad = board.FindFootprintByReference(f"TP{index}")
        if test_pad is None:
            raise AssertionError(f"TP{index} is missing")
        if not test_pad.IsExcludedFromBOM() or not test_pad.IsExcludedFromPosFiles():
            raise AssertionError(f"TP{index} must be PCB-only and excluded from assembly outputs")
        if test_pad.IsDNP():
            raise AssertionError(f"TP{index} is PCB copper, not a DNP component")


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
    audit_release_geometry(board)

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
    print("PASS release geometry: 1.6 mm board, closed outline, reviewed J1/J2, PCB-only TP1-TP8")
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
