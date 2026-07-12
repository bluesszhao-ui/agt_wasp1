#!/usr/bin/env python3
"""Update the editable core_int_datapath diagram for debug execution state."""

from pathlib import Path
import plistlib


ROOT = Path(__file__).resolve().parents[2]
DIAGRAM = ROOT / "core/docs/diagrams/core_int_datapath_block.graffle"
BLACK = {"r": 0.0, "g": 0.0, "b": 0.0, "space": "srgb"}
STROKE = {"r": 0.18, "g": 0.18, "b": 0.18, "space": "srgb"}
IF_FILL = {"r": 0.79, "g": 0.90, "b": 1.0, "space": "srgb"}
SEQ_FILL = {"r": 0.78, "g": 0.95, "b": 0.82, "space": "srgb"}


def rtf(text: str) -> str:
    """Return centered, editable text accepted by OmniGraffle 7."""

    body = text.replace("\\", "\\\\").replace("\n", "\\\n")
    return (
        "{\\rtf1\\ansi\\ansicpg936\\cocoartf2870\n"
        "{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n"
        "{\\colortbl;\\red0\\green0\\blue0;}\n"
        "\\pard\\qc\\partightenfactor0\n\n"
        f"\\f0\\fs16 \\cf0 {body}}}"
    )


def shape(graphic_id: int, name: str, bounds, text: str, fill):
    """Create a native editable OmniGraffle node on the 5pt grid."""

    return {
        "Class": "ShapedGraphic",
        "ID": graphic_id,
        "Name": name,
        "Bounds": f"{{{{{bounds[0]}, {bounds[1]}}}, {{{bounds[2]}, {bounds[3]}}}}}",
        "Style": {
            "fill": {"Color": fill},
            "shadow": {"Draws": "NO"},
            "stroke": {"Color": STROKE, "Width": 1.5},
        },
        "Text": {"Text": rtf(text)},
    }


def line(graphic_id: int, route_name: str, suffix: str, p0, p1):
    """Create a native two-point line with no automatic connector metadata."""

    return {
        "Class": "LineGraphic",
        "ID": graphic_id,
        "Name": f"manual-conn-line-{route_name}-{suffix}",
        "Points": [f"{{{p0[0]}, {p0[1]}}}", f"{{{p1[0]}, {p1[1]}}}"],
        "Style": {
            "shadow": {"Draws": "NO"},
            "stroke": {"Color": BLACK, "Width": 1.5},
        },
    }


def route(graphics, next_id: int, name: str, points, direction: str) -> int:
    """Append orthogonal body segments and a two-line V arrowhead."""

    for segment, (p0, p1) in enumerate(zip(points, points[1:])):
        graphics.append(line(next_id, name, f"s{segment}", p0, p1))
        next_id += 1

    tip = points[-1]
    tails = {
        "right": [(tip[0] - 10, tip[1] - 5), (tip[0] - 10, tip[1] + 5)],
        "left": [(tip[0] + 10, tip[1] - 5), (tip[0] + 10, tip[1] + 5)],
        "down": [(tip[0] - 5, tip[1] - 10), (tip[0] + 5, tip[1] - 10)],
        "up": [(tip[0] - 5, tip[1] + 10), (tip[0] + 5, tip[1] + 10)],
    }[direction]
    graphics.append(line(next_id, name, "arrow-a", tails[0], tip))
    graphics.append(line(next_id + 1, name, "arrow-b", tails[1], tip))
    return next_id + 2


def main() -> None:
    """Replace the historical debug corner with explicit IF/COMB/SEQ blocks."""

    with DIAGRAM.open("rb") as stream:
        document = plistlib.load(stream)

    graphics = []
    for graphic in document["GraphicsList"]:
        name = graphic.get("Name", "")
        if name.startswith("manual-conn-line-debug-to-pipe"):
            continue
        if name == "if-irq":
            graphic["Text"] = {"Text": rtf("IF IRQ/control\ntimer external\nhalt/resume/trigger")}
        elif name == "comb-debug":
            graphic["Text"] = {"Text": rtf(
                "COMB debug admission/isolation\nrequest arbitration + freeze override\ntrap/redirect/DPC suppression"
            )}
        elif name == "seq-csr":
            graphic["Text"] = {"Text": rtf(
                "SEQ CSR/DPC state\nclk=clk_i rst=rst_ni\nmachine CSR + DPC/cause"
            )}
        elif name == "note":
            graphic["Text"] = {"Text": rtf(
                "L3 integration: normal instruction flow is left-to-right. Debug execution stays halted: IF request -> COMB admission -> SEQ active/response -> tagged core_pipe word; ex_debug suppresses normal trap, redirect, DPC, and retire accounting."
            )}
        graphics.append(graphic)

    graphics.append(shape(
        200, "if-debug-exec", (1490, 470, 240, 90),
        "IF debug execution channel\nreq instr/index valid/ready\nrsp valid/ready/error", IF_FILL
    ))
    graphics.append(shape(
        201, "seq-debug-exec", (1790, 460, 240, 100),
        "SEQ debug execution state\nclk=clk_i rst=rst_ni\nactive + response valid/error", SEQ_FILL
    ))

    next_id = 202
    next_id = route(graphics, next_id, "debug-comb-to-exec-state",
                    [(1910, 395), (1910, 460)], "down")
    next_id = route(graphics, next_id, "debug-exec-req",
                    [(1730, 490), (1790, 490)], "right")
    next_id = route(graphics, next_id, "debug-exec-rsp",
                    [(1790, 530), (1730, 530)], "left")
    route(graphics, next_id, "debug-state-to-pipe",
          [(1790, 545), (1760, 545), (1760, 630), (290, 630),
           (290, 180), (320, 180)], "right")

    document["GraphicsList"] = graphics
    with DIAGRAM.open("wb") as stream:
        plistlib.dump(document, stream, fmt=plistlib.FMT_XML, sort_keys=False)


if __name__ == "__main__":
    main()
