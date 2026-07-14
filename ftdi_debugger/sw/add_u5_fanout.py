#!/usr/bin/env python3
"""Add deterministic local fanouts before global autorouting.

The 1.4 mm UQFN package cannot be escaped reliably by the coarse global
autorouter grid.  Short front-copper necks spread all ten pins onto a staggered
ring of through vias; the global router can then start from those accessible
points without changing the reviewed package placement.  The same pass also
bridges U6's two protected-VBUS pins around the intervening ground pin.
"""

from __future__ import annotations

from pathlib import Path
import argparse

import pcbnew


# Each row is net name, package-pad point, optional bend points, and via point.
# Coordinates are millimetres and intentionally asymmetric so adjacent 0.6 mm
# vias retain the required 0.2 mm copper clearance.
FANOUT_PATHS = (
    ("GND", ((93.40, 49.80), (92.85, 49.80), (92.00, 49.40))),
    ("SHIFT_OE_N", ((93.35, 50.20), (92.80, 50.20), (91.60, 50.60))),
    ("GND", ((93.60, 50.85), (93.35, 51.10), (92.80, 51.80))),
    ("UART_TXD", ((94.00, 50.85), (94.00, 51.35), (94.00, 52.60))),
    ("TDO", ((94.40, 50.85), (94.65, 51.10), (95.20, 51.80))),
    ("VREF", ((94.65, 50.20), (95.20, 50.20), (96.40, 50.60))),
    ("VCC_3V3", ((94.65, 49.80), (95.20, 49.80), (96.00, 49.40))),
    ("FT_A_TDO", ((94.40, 49.15), (94.65, 48.90), (95.20, 48.20))),
    ("FT_B_RXD", ((94.00, 49.15), (94.00, 48.65), (94.00, 47.40))),
    ("GND", ((93.60, 49.15), (93.35, 48.90), (92.80, 48.20))),
)

TRACK_WIDTH_MM = {
    "GND": 0.25,
    "TDO": 0.25,
    "VREF": 0.25,
    "VCC_3V3": 0.25,
    "FT_A_TDO": 0.25,
}


def point_mm(x: float, y: float) -> pcbnew.VECTOR2I:
    """Convert a millimetre coordinate pair to KiCad internal units."""
    return pcbnew.VECTOR2I(pcbnew.FromMM(x), pcbnew.FromMM(y))


def add_track(
    board: pcbnew.BOARD,
    net: pcbnew.NETINFO_ITEM,
    start: tuple[float, float],
    end: tuple[float, float],
    width_mm: float,
) -> None:
    """Add and lock one front-copper fanout segment."""
    track = pcbnew.PCB_TRACK(board)
    track.SetStart(point_mm(*start))
    track.SetEnd(point_mm(*end))
    track.SetWidth(pcbnew.FromMM(width_mm))
    track.SetLayer(pcbnew.F_Cu)
    track.SetNet(net)
    track.SetLocked(True)
    board.Add(track)


def add_via(
    board: pcbnew.BOARD,
    net: pcbnew.NETINFO_ITEM,
    position: tuple[float, float],
    diameter_mm: float = 0.60,
    drill_mm: float = 0.30,
) -> None:
    """Add and lock one full-stack fanout via."""
    via = pcbnew.PCB_VIA(board)
    via.SetPosition(point_mm(*position))
    via.SetLayerPair(pcbnew.F_Cu, pcbnew.B_Cu)
    via.SetWidth(pcbnew.FromMM(diameter_mm))
    via.SetDrill(pcbnew.FromMM(drill_mm))
    via.SetNet(net)
    via.SetLocked(True)
    board.Add(via)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("board", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    board = pcbnew.LoadBoard(str(args.board.resolve()))
    if list(board.GetTracks()):
        raise ValueError("U5 fanout must be applied before global routing")

    for net_name, path in FANOUT_PATHS:
        net = board.FindNet(net_name)
        if net is None:
            raise ValueError(f"board is missing U5 fanout net {net_name}")
        width_mm = TRACK_WIDTH_MM.get(net_name, 0.20)
        for start, end in zip(path, path[1:]):
            add_track(board, net, start, end, width_mm)
        add_via(board, net, path[-1])

    # U6 pins 1 and 3 share VBUS_PROTECTED but sit on opposite sides of pin 2
    # (GND).  Escape them in opposite directions and bridge them on In2.Cu so
    # the global router never needs to squeeze a 0.5 mm power track past GND.
    vbus = board.FindNet("VBUS_PROTECTED")
    if vbus is None:
        raise ValueError("board is missing U6 protected-VBUS net")
    upper_path = ((36.8625, 29.05), (36.00, 28.20), (35.50, 27.60))
    lower_path = ((36.8625, 30.95), (36.80, 31.60), (37.40, 32.40))
    for path in (upper_path, lower_path):
        for start, end in zip(path, path[1:]):
            add_track(board, vbus, start, end, 0.50)
        add_via(board, vbus, path[-1], 0.80, 0.40)
    bridge = pcbnew.PCB_TRACK(board)
    bridge.SetStart(point_mm(*upper_path[-1]))
    bridge.SetEnd(point_mm(*lower_path[-1]))
    bridge.SetWidth(pcbnew.FromMM(0.50))
    bridge.SetLayer(pcbnew.In2_Cu)
    bridge.SetNet(vbus)
    bridge.SetLocked(True)
    board.Add(bridge)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    pcbnew.SaveBoard(str(args.output.resolve()), board)
    print(f"PASS added {len(FANOUT_PATHS)} U5 fanout vias and the U6 VBUS bridge")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
