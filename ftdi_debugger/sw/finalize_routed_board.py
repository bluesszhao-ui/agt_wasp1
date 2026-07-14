#!/usr/bin/env python3
"""Add the reviewed VBUS tree and continuous inner-layer ground plane."""

from __future__ import annotations

from pathlib import Path
import argparse

import pcbnew


def point_mm(x: float, y: float) -> pcbnew.VECTOR2I:
    """Convert millimetre coordinates to KiCad internal units."""
    return pcbnew.VECTOR2I(pcbnew.FromMM(x), pcbnew.FromMM(y))


def add_track(
    board: pcbnew.BOARD,
    net: pcbnew.NETINFO_ITEM,
    layer: int,
    width_mm: float,
    path: tuple[tuple[float, float], ...],
) -> None:
    """Add locked two-point segments along a reviewed route."""
    for start, end in zip(path, path[1:]):
        track = pcbnew.PCB_TRACK(board)
        track.SetStart(point_mm(*start))
        track.SetEnd(point_mm(*end))
        track.SetWidth(pcbnew.FromMM(width_mm))
        track.SetLayer(layer)
        track.SetNet(net)
        track.SetLocked(True)
        board.Add(track)


def add_via(
    board: pcbnew.BOARD,
    net: pcbnew.NETINFO_ITEM,
    position: tuple[float, float],
    diameter_mm: float,
    drill_mm: float,
) -> None:
    """Add one locked full-stack through via."""
    via = pcbnew.PCB_VIA(board)
    via.SetPosition(point_mm(*position))
    via.SetLayerPair(pcbnew.F_Cu, pcbnew.B_Cu)
    via.SetWidth(pcbnew.FromMM(diameter_mm))
    via.SetDrill(pcbnew.FromMM(drill_mm))
    via.SetNet(net)
    via.SetLocked(True)
    board.Add(via)


def replace_cc2_route(
    board: pcbnew.BOARD,
    original_tracks: list[pcbnew.BOARD_ITEM],
) -> None:
    """Move CC2 away from the lower USB-C VBUS escape."""
    net = board.FindNet("CC2")
    if net is None:
        raise ValueError("board is missing CC2")
    old_items = [item for item in original_tracks if item.GetNetname() == "CC2"]
    if not old_items:
        raise ValueError("expected an autorouted CC2 connection")
    for item in old_items:
        board.Remove(item)

    # Leave the connector above VBUS, transition to B.Cu after sufficient
    # clearance from D+/D-, and return to F.Cu beside RCC2.
    add_track(board, net, pcbnew.F_Cu, 0.20, ((23.68, 51.75), (29.00, 51.75)))
    add_via(board, net, (29.00, 51.75), 0.60, 0.30)
    add_track(
        board, net, pcbnew.B_Cu, 0.20,
        ((29.00, 51.75), (31.00, 53.75), (31.00, 58.00), (28.49, 59.80)),
    )
    add_via(board, net, (28.49, 59.80), 0.60, 0.30)
    add_track(board, net, pcbnew.F_Cu, 0.20, ((28.49, 59.80), (28.49, 61.00)))


def tune_usb_dm_length(
    board: pcbnew.BOARD,
    original_tracks: list[pcbnew.BOARD_ITEM],
) -> None:
    """Add 0.331 mm to connector-side D- for less than 0.5 mm pair skew."""
    candidates = []
    for item in original_tracks:
        if isinstance(item, pcbnew.PCB_VIA) or item.GetNetname() != "USB_DM_CONN":
            continue
        start = item.GetStart()
        end = item.GetEnd()
        y_values = (pcbnew.ToMM(start.y), pcbnew.ToMM(end.y))
        x_values = (pcbnew.ToMM(start.x), pcbnew.ToMM(end.x))
        if (
            item.GetLayer() == pcbnew.F_Cu
            and all(abs(y - 49.05) < 0.001 for y in y_values)
            and max(x_values) > 28.8
            and min(x_values) < 25.1
        ):
            candidates.append(item)
    if len(candidates) != 1:
        raise ValueError(f"expected one USB_DM_CONN tuning segment, observed {len(candidates)}")
    board.Remove(candidates[0])
    net = board.FindNet("USB_DM_CONN")
    add_track(
        board, net, pcbnew.F_Cu, 0.20,
        ((28.8625, 49.05), (27.20, 49.05), (26.80, 48.65),
         (26.40, 49.05), (25.0256, 49.05)),
    )


def add_vbus_tree(board: pcbnew.BOARD) -> None:
    """Route USB VBUS on In2.Cu between J1, ESD1, and F1."""
    net = board.FindNet("USB_VBUS")
    if net is None:
        raise ValueError("board is missing USB_VBUS")

    # Each device first leaves its pad on F.Cu before transitioning through a
    # 0.8/0.4 mm power via.  This keeps the inner power tree away from signal
    # pads while preserving a 0.5 mm current path throughout.
    front_necks = (
        ((23.68, 47.60), (25.00, 47.60)),
        ((23.68, 52.40), (27.00, 52.40)),
        ((31.1375, 50.00), (32.20, 50.00)),
        ((24.8625, 30.00), (24.8625, 31.20)),
    )
    for path in front_necks:
        add_track(board, net, pcbnew.F_Cu, 0.50, path)
        add_via(board, net, path[-1], 0.80, 0.40)

    # The two connector branches meet at x=27 mm.  A separate trunk rises to
    # the fuse while the short horizontal branch feeds the ESD device.
    add_track(
        board, net, pcbnew.In2_Cu, 0.50,
        ((25.00, 47.60), (27.00, 49.60), (27.00, 50.00),
         (27.00, 50.40), (27.00, 52.40)),
    )
    add_track(board, net, pcbnew.In2_Cu, 0.50, ((27.00, 50.00), (32.20, 50.00)))
    add_track(
        board, net, pcbnew.In2_Cu, 0.50,
        ((27.00, 50.00), (26.00, 49.00), (26.00, 32.3375), (24.8625, 31.20)),
    )


def add_ground_plane(board: pcbnew.BOARD) -> None:
    """Create and fill a continuous In1.Cu ground reference plane."""
    net = board.FindNet("GND")
    if net is None:
        raise ValueError("board is missing GND")
    zone = pcbnew.ZONE(board)
    zone.SetLayer(pcbnew.In1_Cu)
    zone.SetNet(net)
    zone.SetZoneName("GND_PLANE_IN1")
    zone.SetLocalClearance(pcbnew.FromMM(0.20))
    zone.SetMinThickness(pcbnew.FromMM(0.25))
    zone.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
    outline = pcbnew.VECTOR_VECTOR2I()
    for corner in ((15.50, 20.50), (124.50, 20.50), (124.50, 84.50), (15.50, 84.50)):
        outline.append(point_mm(*corner))
    zone.AddPolygon(outline)
    board.Add(zone)
    if not pcbnew.ZONE_FILLER(board).Fill(board.Zones()):
        raise RuntimeError("failed to fill In1.Cu ground plane")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("board", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    board = pcbnew.LoadBoard(str(args.board.resolve()))
    original_tracks = list(board.GetTracks())
    tune_usb_dm_length(board, original_tracks)
    replace_cc2_route(board, original_tracks)
    add_vbus_tree(board)
    add_ground_plane(board)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    pcbnew.SaveBoard(str(args.output.resolve()), board)
    print("PASS added USB VBUS tree, rerouted CC2, and filled GND plane")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
