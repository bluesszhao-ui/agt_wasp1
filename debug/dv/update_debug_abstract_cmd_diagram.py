#!/usr/bin/env python3
"""Extend the debug_abstract_cmd L3 diagram with postexec connectivity."""

from pathlib import Path
import plistlib

from generate_debug_progbuf_exec_diagram import IF_FILL, NOTE_FILL, route, rtf, shape


ROOT = Path(__file__).resolve().parents[2]
DIAGRAM = ROOT / "debug/docs/diagrams/debug_abstract_cmd_fsm.graffle"


def main() -> None:
    """Add the executor IF and update the registered FSM description."""

    with DIAGRAM.open("rb") as stream:
        document = plistlib.load(stream)

    graphics = []
    for graphic in document["GraphicsList"]:
        name = graphic.get("Name", "")
        if name == "if-progbuf-exec" or name.startswith(
            "manual-conn-line-fsm-to-progbuf-start"
        ) or name.startswith(
            "manual-conn-line-progbuf-done-to-complete"
        ) or name.startswith("manual-conn-line-report-flush-to-reg"):
            continue
        if name == "seq-fsm":
            graphic["Text"] = {"Text": rtf(
                "SEQ abstract FSM\nclk=clk_i rst=rst_ni\nIDLE ISSUE WAIT\nPOSTEXEC_START/WAIT COMPLETE"
            )}
        elif name == "note":
            graphic["Bounds"] = "{{40, 600}, {1300, 70}}"
            graphic["Text"] = {"Text": rtf(
                "Postexec ordering: local/no-transfer commands enter POSTEXEC_START directly; successful GPR response enters it after WAIT.\nTransfer error suppresses start. Executor done/error is captured before COMPLETE emits data0 or cmderr."
            )}
        graphics.append(graphic)

    graphics.append(shape(
        200, "if-progbuf-exec", (330, 430, 260, 95),
        "IF Program Buffer executor\nstart / done / cmderr\nregistered request-response boundary",
        IF_FILL, None, False
    ))

    next_id = 201
    next_id = route(
        graphics, next_id, "fsm-to-progbuf-start",
        [(790, 90), (790, 60), (20, 60), (20, 475), (330, 475)], "right"
    )
    route(
        graphics, next_id, "progbuf-done-to-complete",
        [(590, 500), (620, 500), (620, 560), (1280, 560),
         (1280, 160), (1250, 160)], "left"
    )

    document["CanvasSize"] = "{1600, 720}"
    document["BackgroundGraphic"]["Bounds"] = "{{0, 0}, {1600, 720}}"
    document["HPages"] = 1
    document["VPages"] = 1
    document["GraphicsList"] = graphics

    with DIAGRAM.open("wb") as stream:
        plistlib.dump(document, stream, fmt=plistlib.FMT_XML, sort_keys=False)


if __name__ == "__main__":
    main()
