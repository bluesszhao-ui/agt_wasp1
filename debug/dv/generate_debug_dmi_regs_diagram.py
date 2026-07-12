#!/usr/bin/env python3
"""Add the DMI-routed Program Buffer path to the editable DMI register diagram."""

from pathlib import Path
import plistlib


ROOT = Path(__file__).resolve().parents[2]
DIAGRAM = ROOT / "debug/docs/diagrams/debug_dmi_regs_block.graffle"

BLACK = {"r": 0.0, "g": 0.0, "b": 0.0, "space": "srgb"}
STROKE = {"r": 0.18, "g": 0.18, "b": 0.18, "space": "srgb"}
IF_FILL = {"r": 0.79, "g": 0.90, "b": 1.0, "space": "srgb"}
SEQ_FILL = {"r": 0.78, "g": 0.95, "b": 0.82, "space": "srgb"}
NOTE_FILL = {"r": 0.94, "g": 0.94, "b": 0.94, "space": "srgb"}


def rtf(text: str) -> str:
    """Return centered RTF text that remains editable in OmniGraffle."""

    body = text.replace("\\", "\\\\").replace("\n", "\\\n")
    return (
        "{\\rtf1\\ansi\\ansicpg936\\cocoartf2870\n"
        "{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n"
        "{\\colortbl;\\red0\\green0\\blue0;}\n"
        "\\pard\\qc\\partightenfactor0\n\n"
        f"\\f0\\fs16 \\cf0 {body}}}"
    )


def shape(graphic_id, name, bounds, text, fill):
    """Create one grid-aligned native shape."""

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


def line(graphic_id, route_name, segment, p0, p1, arrow_part=None):
    """Create one native two-point body or V-arrow line."""

    suffix = f"-arrow-{arrow_part}" if arrow_part else f"-s{segment}"
    return {
        "Class": "LineGraphic",
        "ID": graphic_id,
        "Name": f"manual-conn-line-{route_name}{suffix}",
        "Points": [f"{{{p0[0]}, {p0[1]}}}", f"{{{p1[0]}, {p1[1]}}}"],
        "Style": {
            "shadow": {"Draws": "NO"},
            "stroke": {"Color": BLACK, "Width": 1.5},
        },
    }


def append_route(graphics, graphic_id, name, points, direction):
    """Append orthogonal body segments and an endpoint-aligned V arrow."""

    for segment, (p0, p1) in enumerate(zip(points, points[1:])):
        graphics.append(line(graphic_id, name, segment, p0, p1))
        graphic_id += 1

    tip = points[-1]
    tails = {
        "right": [(tip[0] - 10, tip[1] - 5), (tip[0] - 10, tip[1] + 5)],
        "left": [(tip[0] + 10, tip[1] - 5), (tip[0] + 10, tip[1] + 5)],
        "down": [(tip[0] - 5, tip[1] - 10), (tip[0] + 5, tip[1] - 10)],
    }[direction]
    graphics.append(line(graphic_id, name, 0, tails[0], tip, "a"))
    graphics.append(line(graphic_id + 1, name, 0, tails[1], tip, "b"))
    return graphic_id + 2


def main():
    """Regenerate the additional Program Buffer shapes and routes idempotently."""

    with DIAGRAM.open("rb") as stream:
        document = plistlib.load(stream)

    added_names = {"seq-progbuf", "if-progbuf-exec", "progbuf-note"}
    added_routes = (
        "manual-conn-line-abstract-to-progbuf",
        "manual-conn-line-op-to-progbuf",
        "manual-conn-line-progbuf-to-exec",
        "manual-conn-line-progbuf-to-read",
    )
    graphics = [
        graphic for graphic in document["GraphicsList"]
        if graphic.get("Name") not in added_names and
        not str(graphic.get("Name", "")).startswith(added_routes)
    ]
    for graphic in graphics:
        if graphic.get("Name") == "seq-abstract":
            graphic["Text"] = {"Text": rtf(
                "SEQ abstract regs\nclk=clk_i rst=rst_ni\n"
                "command data0 data1 cmderr\nbusy read/write policy"
            )}
        elif graphic.get("Name") == "comb-read":
            graphic["Text"] = {"Text": rtf(
                "COMB read images/mux\ndmcontrol dmstatus\n"
                "abstractcs data0 data1 progbuf\naddr selects image"
            )}
    graphic_id = max(graphic.get("ID", 0) for graphic in graphics) + 1

    graphics.append(shape(
        graphic_id,
        "seq-progbuf",
        (640, 650, 250, 110),
        "SEQ Program Buffer storage\nclk=clk_i rst=rst_ni\n4 x 32-bit words\nclear > accepted idle write > hold",
        SEQ_FILL,
    ))
    graphic_id += 1
    graphics.append(shape(
        graphic_id,
        "if-progbuf-exec",
        (1240, 655, 220, 100),
        "IF future Program Buffer executor\nfull four-word array\nexecution not advertised yet",
        IF_FILL,
    ))
    graphic_id += 1
    graphics.append(shape(
        graphic_id,
        "progbuf-note",
        (40, 650, 470, 70),
        "DMI progbuf0..3 are internally routed.\nBusy reads set cmderr=BUSY; busy writes also preserve storage.\nabstractcs.progbufsize remains zero until core execution passes.",
        NOTE_FILL,
    ))
    graphic_id += 1

    graphic_id = append_route(
        graphics,
        graphic_id,
        "abstract-to-progbuf",
        [(700, 570), (700, 650)],
        "down",
    )
    graphic_id = append_route(
        graphics,
        graphic_id,
        "progbuf-to-exec",
        [(890, 705), (1240, 705)],
        "right",
    )
    append_route(
        graphics,
        graphic_id,
        "progbuf-to-read",
        [(800, 650), (800, 620), (1530, 620), (1530, 150), (1500, 150)],
        "left",
    )

    document["CanvasSize"] = "{1680, 820}"
    document["BackgroundGraphic"]["Bounds"] = "{{0, 0}, {1680, 820}}"
    document["HPages"] = 1
    document["VPages"] = 1
    document["GraphicsList"] = graphics

    with DIAGRAM.open("wb") as stream:
        plistlib.dump(document, stream, fmt=plistlib.FMT_XML, sort_keys=False)


if __name__ == "__main__":
    main()
