#!/usr/bin/env python3
"""Generate the editable, grid-audited debug top L3 integration diagram."""

from pathlib import Path
import plistlib

from generate_debug_progbuf_exec_diagram import (
    COMB_FILL,
    IF_FILL,
    NOTE_FILL,
    SEQ_FILL,
    route,
    shape,
)


ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "debug/docs/diagrams/debug_progbuf_exec_fsm.graffle"
OUTPUT = ROOT / "debug/docs/diagrams/debug_block.graffle"


def main() -> None:
    """Build a single-page IF/COMB/SEQ ownership and dataflow diagram."""

    with TEMPLATE.open("rb") as stream:
        document = plistlib.load(stream)

    graphics = []
    graphic_id = 100
    nodes = [
        ("title", (40, 20, 1050, 30),
         "debug top / DMI, abstract command, Program Buffer, and core Debug Mode integration",
         NOTE_FILL, None, True),
        ("if-dmi", (40, 280, 200, 90),
         "IF DMI\nrequest/response\nfrom JTAG DTM", IF_FILL, None, False),
        ("seq-dmi-regs", (300, 270, 250, 110),
         "SEQ debug_dmi_regs\nclk=clk_i rst=rst_ni\ncontrol/data/cmderr/progbuf", SEQ_FILL, None, False),
        ("seq-halt", (650, 70, 240, 100),
         "SEQ debug_halt_ctrl\nclk=clk_i rst=rst_ni\nhalt/resume/sticky status", SEQ_FILL, None, False),
        ("seq-abstract", (650, 270, 260, 120),
         "SEQ debug_abstract_cmd\nclk=clk_i rst=rst_ni\ntransfer + POSTEXEC_START/WAIT", SEQ_FILL, None, False),
        ("seq-reg", (1000, 70, 240, 100),
         "SEQ debug_reg_access\nclk=clk_i rst=rst_ni\nGPR request/response", SEQ_FILL, None, False),
        ("seq-progbuf", (650, 480, 260, 110),
         "SEQ debug_progbuf_exec\nclk=clk_i rst=rst_ni\nCHECK/ISSUE/WAIT/COMPLETE", SEQ_FILL, None, False),
        ("if-core", (1300, 230, 250, 180),
         "IF core_debug\nhalt/resume/status\nGPR + memory\ntrigger configuration\nexec request/response", IF_FILL, None, False),
        ("comb-bridge", (1000, 270, 240, 120),
         "COMB wrapper ownership bridges\nstep/trigger/GPR/memory/exec\nno wrapper-owned state", COMB_FILL, None, False),
        ("note", (130, 680, 1350, 60),
         "Postexec path: DMI progbuf words -> debug_dmi_regs storage -> abstract start -> progbuf executor -> core_debug exec channel.\nabstractcs.busy protects payload until EBREAK success or executor cmderr; abstractauto is WARL-zero.",
         NOTE_FILL, None, False),
    ]

    for name, bounds, text, fill, kind, bold in nodes:
        graphics.append(shape(graphic_id, name, bounds, text, fill, kind, bold))
        graphic_id += 1

    graphic_id = route(graphics, graphic_id, "dmi-to-regs",
                       [(240, 325), (300, 325)], "right")
    graphic_id = route(graphics, graphic_id, "regs-to-halt",
                       [(425, 270), (425, 120), (650, 120)], "right")
    graphic_id = route(graphics, graphic_id, "regs-to-abstract",
                       [(550, 325), (650, 325)], "right")
    graphic_id = route(graphics, graphic_id, "abstract-to-reg",
                       [(910, 300), (960, 300), (960, 120), (1000, 120)], "right")
    graphic_id = route(graphics, graphic_id, "regs-words-to-progbuf",
                       [(425, 380), (425, 535), (650, 535)], "right")
    graphic_id = route(graphics, graphic_id, "abstract-to-progbuf",
                       [(780, 390), (780, 480)], "down")

    # Main wrapper flow and independent outer channels avoid all unrelated
    # shape and line crossings.
    graphic_id = route(graphics, graphic_id, "halt-to-bridge",
                       [(770, 70), (770, 60), (1425, 60), (1425, 230)], "down")
    graphic_id = route(graphics, graphic_id, "reg-to-bridge",
                       [(1120, 170), (1120, 270)], "down")
    graphic_id = route(graphics, graphic_id, "abstract-to-bridge",
                       [(910, 350), (1000, 350)], "right")
    graphic_id = route(graphics, graphic_id, "progbuf-to-bridge",
                       [(910, 530), (960, 530), (960, 420), (1120, 420),
                        (1120, 390)], "up")
    route(graphics, graphic_id, "bridge-to-core",
          [(1240, 330), (1300, 330)], "right")

    document["CanvasSize"] = "{1600, 760}"
    document["BackgroundGraphic"]["Bounds"] = "{{0, 0}, {1600, 760}}"
    document["HPages"] = 1
    document["VPages"] = 1
    document["GraphicsList"] = graphics

    with OUTPUT.open("wb") as stream:
        plistlib.dump(document, stream, fmt=plistlib.FMT_XML, sort_keys=False)


if __name__ == "__main__":
    main()
