#!/usr/bin/env python3
"""Generate the editable, grid-audited debug_progbuf_exec L3 diagram."""

from pathlib import Path
import plistlib


ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "debug/docs/diagrams/debug_reg_access_fsm.graffle"
OUTPUT = ROOT / "debug/docs/diagrams/debug_progbuf_exec_fsm.graffle"

BLACK = {"r": 0.0, "g": 0.0, "b": 0.0, "space": "srgb"}
STROKE = {"r": 0.18, "g": 0.18, "b": 0.18, "space": "srgb"}
IF_FILL = {"r": 0.79, "g": 0.90, "b": 1.0, "space": "srgb"}
COMB_FILL = {"r": 1.0, "g": 0.90, "b": 0.66, "space": "srgb"}
SEQ_FILL = {"r": 0.78, "g": 0.95, "b": 0.82, "space": "srgb"}
NOTE_FILL = {"r": 0.94, "g": 0.94, "b": 0.94, "space": "srgb"}


def rtf(text: str, bold: bool = False) -> str:
    """Return minimal centered RTF accepted by OmniGraffle 7."""

    body = text.replace("\\", "\\\\").replace("\n", "\\\n")
    weight = "\\b" if bold else ""
    return (
        "{\\rtf1\\ansi\\ansicpg936\\cocoartf2870\n"
        "{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n"
        "{\\colortbl;\\red0\\green0\\blue0;}\n"
        "\\pard\\qc\\partightenfactor0\n\n"
        f"\\f0{weight}\\fs16 \\cf0 {body}}}"
    )


def shape(graphic_id, name, bounds, text, fill, kind=None, bold=False):
    """Create one native editable OmniGraffle shape."""

    graphic = {
        "Class": "ShapedGraphic",
        "ID": graphic_id,
        "Name": name,
        "Bounds": f"{{{{{bounds[0]}, {bounds[1]}}}, {{{bounds[2]}, {bounds[3]}}}}}",
        "Style": {
            "fill": {"Color": fill},
            "shadow": {"Draws": "NO"},
            "stroke": {"Color": STROKE, "Width": 1.5},
        },
        "Text": {"Text": rtf(text, bold)},
    }
    if kind is not None:
        graphic["Shape"] = kind
    return graphic


def line(graphic_id, route, segment, p0, p1, arrow_part=None):
    """Create one native two-point line without connector metadata."""

    suffix = f"-arrow-{arrow_part}" if arrow_part else f"-s{segment}"
    return {
        "Class": "LineGraphic",
        "ID": graphic_id,
        "Name": f"manual-conn-line-{route}{suffix}",
        "Points": [f"{{{p0[0]}, {p0[1]}}}", f"{{{p1[0]}, {p1[1]}}}"],
        "Style": {
            "shadow": {"Draws": "NO"},
            "stroke": {"Color": BLACK, "Width": 1.5},
        },
    }


def route(graphics, next_id, name, points, direction):
    """Append orthogonal body segments and a two-line V arrowhead."""

    for segment, (p0, p1) in enumerate(zip(points, points[1:])):
        graphics.append(line(next_id, name, segment, p0, p1))
        next_id += 1

    tip = points[-1]
    tails = {
        "right": [(tip[0] - 10, tip[1] - 5), (tip[0] - 10, tip[1] + 5)],
        "left": [(tip[0] + 10, tip[1] - 5), (tip[0] + 10, tip[1] + 5)],
        "down": [(tip[0] - 5, tip[1] - 10), (tip[0] + 5, tip[1] - 10)],
        "up": [(tip[0] - 5, tip[1] + 10), (tip[0] + 5, tip[1] + 10)],
    }[direction]
    graphics.append(line(next_id, name, 0, tails[0], tip, "a"))
    graphics.append(line(next_id + 1, name, 0, tails[1], tip, "b"))
    return next_id + 2


def main():
    """Build the single-page diagram from deterministic grid coordinates."""

    with TEMPLATE.open("rb") as stream:
        document = plistlib.load(stream)

    graphics = []
    graphic_id = 100

    nodes = [
        ("title", (40, 20, 1100, 30), "debug_progbuf_exec editable L3 FSM and timing-class diagram", NOTE_FILL, None, True),
        ("if-control", (40, 80, 220, 100), "IF control/storage\nstart_i dmactive_i\nhart_halted_i words_i", IF_FILL, None, False),
        ("comb-policy", (330, 75, 240, 110), "COMB policy/decode\nEBREAK and last-word detect\nabort/error priority", COMB_FILL, None, False),
        ("seq-registers", (660, 70, 280, 120), "SEQ state/index/error registers\nclk=clk_i rst=rst_ni\nreset and DM-abort scrub", SEQ_FILL, None, False),
        ("comb-handshake", (1030, 75, 240, 110), "COMB handshake/report\ninstr valid/ready gating\nbusy done error", COMB_FILL, None, False),
        ("if-core", (1350, 80, 230, 100), "IF halted core\ninstr request\ncompletion/error response", IF_FILL, None, False),
        ("state-idle", (60, 330, 180, 80), "SEQ IDLE\nclk=clk_i rst=rst_ni", SEQ_FILL, "Circle", False),
        ("state-check", (350, 330, 180, 80), "SEQ CHECK\nclk=clk_i rst=rst_ni", SEQ_FILL, "Circle", False),
        ("state-issue", (660, 330, 180, 80), "SEQ ISSUE\nclk=clk_i rst=rst_ni", SEQ_FILL, "Circle", False),
        ("state-wait", (970, 330, 180, 80), "SEQ WAIT\nclk=clk_i rst=rst_ni", SEQ_FILL, "Circle", False),
        ("state-complete", (1300, 330, 180, 80), "SEQ COMPLETE\nclk=clk_i rst=rst_ni", SEQ_FILL, "Circle", False),
        ("reset-marker", (90, 270, 120, 40), "RESET\n!rst_ni", NOTE_FILL, "Circle", False),
        ("label-idle-check", (60, 205, 260, 30), "start_i && dmactive_i && hart_halted_i", NOTE_FILL, None, False),
        ("label-check-issue", (535, 285, 250, 30), "current word != EBREAK", NOTE_FILL, None, False),
        ("label-issue-wait", (845, 285, 220, 30), "instr_valid_o && instr_ready_i", NOTE_FILL, None, False),
        ("label-wait-complete", (1090, 425, 250, 40), "rsp_fire &&\n(rsp_error || current_is_last)", NOTE_FILL, None, False),
        ("label-check-complete", (690, 205, 360, 30), "current word == EBREAK: error=NONE", NOTE_FILL, None, False),
        ("label-wait-check", (650, 525, 390, 35), "rsp_fire && !rsp_error && !current_is_last: index++", NOTE_FILL, None, False),
        ("label-idle-complete", (510, 615, 620, 35), "start_i && dmactive_i && !hart_halted_i: error=HALT_RESUME", NOTE_FILL, None, False),
        ("label-complete-idle", (530, 715, 580, 35), "COMPLETE lasts one cycle; done_o=1, then return IDLE", NOTE_FILL, None, False),
        ("global-priority-note", (260, 790, 1060, 70), "Global transition priority in CHECK/ISSUE/WAIT:\n!dmactive_i -> IDLE silently and scrub progress; !hart_halted_i -> COMPLETE/HALT_RESUME.\nWAIT response error or execution past word 3 -> COMPLETE/EXCEPTION. Inactive or busy start_i is ignored.", NOTE_FILL, None, False),
    ]

    for name, bounds, text, fill, kind, bold in nodes:
        graphics.append(shape(graphic_id, name, bounds, text, fill, kind, bold))
        graphic_id += 1

    # Timing-class dataflow across the top row.
    graphic_id = route(graphics, graphic_id, "if-to-policy", [(260, 130), (330, 130)], "right")
    graphic_id = route(graphics, graphic_id, "policy-to-regs", [(570, 130), (660, 130)], "right")
    graphic_id = route(graphics, graphic_id, "regs-to-handshake", [(940, 130), (1030, 130)], "right")
    graphic_id = route(graphics, graphic_id, "handshake-to-core", [(1270, 130), (1350, 130)], "right")

    # Normal forward FSM arcs.
    graphic_id = route(graphics, graphic_id, "idle-to-check", [(240, 370), (350, 370)], "right")
    graphic_id = route(graphics, graphic_id, "check-to-issue", [(530, 370), (660, 370)], "right")
    graphic_id = route(graphics, graphic_id, "issue-to-wait", [(840, 370), (970, 370)], "right")
    graphic_id = route(graphics, graphic_id, "wait-to-complete", [(1150, 370), (1300, 370)], "right")

    # Asynchronous reset returns the registered FSM directly to IDLE.
    graphic_id = route(graphics, graphic_id, "reset-to-idle", [(150, 310), (150, 330)], "down")

    # EBREAK terminates from CHECK without traversing ISSUE/WAIT.
    graphic_id = route(
        graphics, graphic_id, "check-to-complete-ebreak",
        [(440, 330), (440, 250), (1390, 250), (1390, 330)], "down"
    )

    # Successful response advances the index and loops back to CHECK.
    graphic_id = route(
        graphics, graphic_id, "wait-to-check-next",
        [(1060, 410), (1060, 510), (440, 510), (440, 410)], "up"
    )

    # A start while not halted reports HALT_RESUME through COMPLETE.
    graphic_id = route(
        graphics, graphic_id, "idle-to-complete-halt",
        [(150, 410), (150, 600), (1390, 600), (1390, 410)], "up"
    )

    # COMPLETE is a one-cycle reporting state and always returns to IDLE.
    route(
        graphics, graphic_id, "complete-to-idle",
        [(1480, 370), (1550, 370), (1550, 700), (20, 700), (20, 370), (60, 370)], "right"
    )

    document["CanvasSize"] = "{1640, 900}"
    document["BackgroundGraphic"]["Bounds"] = "{{0, 0}, {1640, 900}}"
    document["HPages"] = 1
    document["VPages"] = 1
    document["GraphicsList"] = graphics

    with OUTPUT.open("wb") as stream:
        plistlib.dump(document, stream, fmt=plistlib.FMT_XML, sort_keys=False)


if __name__ == "__main__":
    main()
