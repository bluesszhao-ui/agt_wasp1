#!/usr/bin/env python3
"""Import a routed Specctra session into a copy of the native KiCad PCB."""

from __future__ import annotations

from pathlib import Path
import argparse
import shutil

import pcbnew


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("board", type=Path)
    parser.add_argument("session", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.board, args.output)
    board = pcbnew.LoadBoard(str(args.output.resolve()))
    if not pcbnew.ImportSpecctraSES(board, str(args.session.resolve())):
        raise RuntimeError(f"failed to import Specctra session {args.session}")
    pcbnew.SaveBoard(str(args.output.resolve()), board)
    print(f"PASS imported Specctra session: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
