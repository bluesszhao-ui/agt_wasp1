#!/usr/bin/env python3
"""Export the native KiCad PCB to a Specctra DSN routing interchange file."""

from __future__ import annotations

from pathlib import Path
import argparse

import pcbnew


NETCLASS_ASSIGNMENTS = {
    "USB_DIFF": ("USB_DP", "USB_DM", "USB_DP_CONN", "USB_DM_CONN"),
    "POWER": ("GND", "VCC_3V3", "VCORE", "VREF"),
    "VBUS": ("USB_VBUS", "VBUS_PROTECTED"),
    "JTAG": (
        "FT_A_NSRST", "FT_A_NTRST", "FT_A_TCK", "FT_A_TDI", "FT_A_TDO", "FT_A_TMS",
        "NSRST_RAW", "NTRST_RAW", "TCK", "TCK_RAW", "TDI", "TDI_RAW", "TDO",
        "TMS", "TMS_RAW", "nSRST", "nTRST",
    ),
}


def apply_explicit_netclasses(board: pcbnew.BOARD) -> None:
    """Make router constraints independent of KiCad pattern interpretation."""
    settings = board.GetDesignSettings().m_NetSettings
    board_nets = {
        net.GetNetname()
        for net in board.GetNetInfo().NetsByName().values()
        if net.GetNetname()
    }
    for netclass, nets in NETCLASS_ASSIGNMENTS.items():
        if not settings.HasNetclass(netclass):
            raise ValueError(f"project does not define required net class {netclass}")
        class_set = pcbnew.STRINGSET()
        class_set.add(netclass)
        for net in nets:
            if net not in board_nets:
                raise ValueError(f"net-class assignment references missing net {net}")
            settings.SetNetclassLabelAssignment(net, class_set)
    settings.RecomputeEffectiveNetclasses()
    board.SynchronizeNetsAndNetClasses(True)

    failures = []
    for expected, nets in NETCLASS_ASSIGNMENTS.items():
        for net in nets:
            observed = board.FindNet(net).GetNetClassName()
            if observed != expected:
                failures.append(f"{net}: expected {expected}, observed {observed}")
    if failures:
        raise ValueError("effective net-class mismatch: " + "; ".join(failures))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("board", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    board = pcbnew.LoadBoard(str(args.board.resolve()))
    apply_explicit_netclasses(board)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if not pcbnew.ExportSpecctraDSN(board, str(args.output.resolve())):
        raise RuntimeError(f"failed to export Specctra DSN to {args.output}")
    print(f"PASS exported Specctra DSN: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
