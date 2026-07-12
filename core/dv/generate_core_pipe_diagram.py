#!/usr/bin/env python3
"""Add the halted-core debug injection path to the editable core_pipe diagram."""

from pathlib import Path
import plistlib


ROOT = Path(__file__).resolve().parents[2]
DIAGRAM = ROOT / "core/docs/diagrams/core_pipe_block.graffle"

BLACK = {"r": 0.0, "g": 0.0, "b": 0.0, "space": "srgb"}
STROKE = {"r": 0.18, "g": 0.18, "b": 0.18, "space": "srgb"}
IF_FILL = {"r": 0.79, "g": 0.90, "b": 1.0, "space": "srgb"}


def rtf(text: str) -> str:
    """Return centered editable OmniGraffle text."""

    body = text.replace("\\", "\\\\").replace("\n", "\\\n")
    return (
        "{\\rtf1\\ansi\\ansicpg936\\cocoartf2870\n"
        "{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n"
        "{\\colortbl;\\red0\\green0\\blue0;}\n"
        "\\pard\\qc\\partightenfactor0\n\n"
        f"\\f0\\fs16 \\cf0 {body}}}"
    )


def shape(graphic_id, name, bounds, text):
    """Create one native grid-aligned IF shape."""

    return {
        "Class": "ShapedGraphic",
        "ID": graphic_id,
        "Name": name,
        "Bounds": f"{{{{{bounds[0]}, {bounds[1]}}}, {{{bounds[2]}, {bounds[3]}}}}}",
        "Style": {
            "fill": {"Color": IF_FILL},
            "shadow": {"Draws": "NO"},
            "stroke": {"Color": STROKE, "Width": 1.5},
        },
        "Text": {"Text": rtf(text)},
    }


def line(graphic_id, name, segment, p0, p1, arrow=None):
    """Create one native body segment or V-arrow half."""

    suffix = f"-arrow-{arrow}" if arrow else f"-s{segment}"
    return {
        "Class": "LineGraphic",
        "ID": graphic_id,
        "Name": f"manual-conn-line-{name}{suffix}",
        "Points": [f"{{{p0[0]}, {p0[1]}}}", f"{{{p1[0]}, {p1[1]}}}"],
        "Style": {
            "shadow": {"Draws": "NO"},
            "stroke": {"Color": BLACK, "Width": 1.5},
        },
    }


def main():
    """Regenerate the additional injection geometry idempotently."""

    with DIAGRAM.open("rb") as stream:
        document = plistlib.load(stream)

    graphics = [
        graphic for graphic in document["GraphicsList"]
        if graphic.get("Name") != "if-debug-inject" and
        not str(graphic.get("Name", "")).startswith("manual-conn-line-debug-to-accept")
    ]

    for graphic in graphics:
        name = graphic.get("Name")
        if name == "comb-accept":
            graphic["Text"] = {"Text": rtf(
                "COMB source accept/arb\ndebug valid suppresses frontend\n"
                "empty-slot debug ready\nstall and redirect gates"
            )}
        elif name == "seq-ifid":
            graphic["Text"] = {"Text": rtf(
                "SEQ IF/ID slot\nclk=clk_i rst=rst_ni\n"
                "pc instr fault valid\ndebug source tag"
            )}
        elif name == "seq-exwb":
            graphic["Text"] = {"Text": rtf(
                "SEQ EX/WB slot\nclk=clk_i rst=rst_ni\n"
                "pc instr fault valid\ndebug source tag"
            )}
        elif name == "note":
            graphic["Text"] = {"Text": rtf(
                "Clock-edge priority: reset > redirect > accepted debug injection > normal flow. "
                "Debug valid excludes frontend acceptance; tags advance and clear with their slots."
            )}

    graphic_id = max(graphic.get("ID", 0) for graphic in graphics) + 1
    graphics.append(shape(
        graphic_id,
        "if-debug-inject",
        (40, 200, 220, 60),
        "IF halted-core debug injection\nvalid/ready pc instr",
    ))
    graphic_id += 1

    points = [(260, 230), (290, 230), (290, 150), (330, 150)]
    for segment, (p0, p1) in enumerate(zip(points, points[1:])):
        graphics.append(line(graphic_id, "debug-to-accept", segment, p0, p1))
        graphic_id += 1
    tip = points[-1]
    graphics.append(line(graphic_id, "debug-to-accept", 0, (320, 145), tip, "a"))
    graphics.append(line(graphic_id + 1, "debug-to-accept", 0, (320, 155), tip, "b"))

    document["GraphicsList"] = graphics
    with DIAGRAM.open("wb") as stream:
        plistlib.dump(document, stream, fmt=plistlib.FMT_XML, sort_keys=False)


if __name__ == "__main__":
    main()
