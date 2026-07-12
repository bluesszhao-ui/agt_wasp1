#!/usr/bin/env python3
"""Generate the editable Rev A FT2232H debugger board block diagram."""

from pathlib import Path
import plistlib
import sys


ROOT = Path(__file__).resolve().parents[2]
DEBUG_DV = ROOT / "debug/dv"
sys.path.insert(0, str(DEBUG_DV))

from generate_debug_progbuf_exec_diagram import (  # noqa: E402
    COMB_FILL,
    IF_FILL,
    NOTE_FILL,
    SEQ_FILL,
    route,
    shape,
)


TEMPLATE = ROOT / "debug/docs/diagrams/debug_progbuf_exec_fsm.graffle"
OUTPUT = ROOT / "ftdi_debugger/docs/diagrams/ftdi_debugger_revA_block.graffle"
POWER_FILL = {"r": "0.95", "g": "0.82", "b": "0.86", "a": "1"}


def main() -> None:
    """Build one page with explicit power, clock, interface, and COMB blocks."""

    with TEMPLATE.open("rb") as stream:
        document = plistlib.load(stream)

    graphics = []
    graphic_id = 100
    nodes = [
        ("title", (40, 20, 1500, 30),
         "wasp1 FT2232H debugger Rev A board architecture and fail-safe target isolation",
         NOTE_FILL, True),
        ("if-usb", (40, 280, 180, 100),
         "IF USB-C J1\nVBUS / D+ / D-\nCC1 / CC2 / shield", IF_FILL, False),
        ("comb-usb-esd", (270, 280, 190, 100),
         "COMB USB protection\nESD1 USBLC6-2SC6\n90 Ohm differential path", COMB_FILL, False),
        ("power", (270, 80, 210, 100),
         "POWER F1 + U6\nUSB VBUS -> 3.3 V\nAP2112K-3.3", POWER_FILL, False),
        ("clock", (590, 70, 190, 90),
         "CLOCK Y1\n12 MHz +/-25 ppm\ndrives U1 OSCI", IF_FILL, False),
        ("eeprom", (870, 70, 190, 90),
         "SEQ U2 EEPROM\nclk=EECLK\n93LC56B optional", SEQ_FILL, False),
        ("ftdi", (590, 220, 280, 200),
         "IF U1 FT2232HL bridge\nclk=FT_CLK12\nChannel A MPSSE JTAG\nChannel B UART\nADBUS6 FT_TARGET_EN", IF_FILL, False),
        ("if-vref", (40, 570, 180, 100),
         "IF target VREF\n1.8 V to 3.3 V\nsense-only rail", IF_FILL, False),
        ("comb-vref", (270, 570, 210, 100),
         "COMB U3 comparator\nTLV7041 threshold 1.57 V\noutput VREF_VALID", COMB_FILL, False),
        ("comb-gate", (900, 650, 180, 80),
         "COMB U7 NAND\nVREF_VALID && TARGET_EN\n-> U4/U5 SHIFT_OE_N", COMB_FILL, False),
        ("comb-out", (990, 230, 230, 160),
         "COMB U4 output translator\nSN74AXC8T245\nVCCA=3.3 V VCCB=VREF\nA->B, OE=SHIFT_OE_N", COMB_FILL, False),
        ("comb-in", (590, 500, 230, 140),
         "COMB U5 input translator\nSN74AXC2T245\nVCCA=3.3 V VCCB=VREF\nB->A, OE=SHIFT_OE_N", COMB_FILL, False),
        ("if-target", (1330, 280, 220, 270),
         "IF keyed target J2\nVREF / GND\nTCK TMS TDI TDO\nnTRST nSRST\nUART_TXD UART_RXD\nESD2 at connector", IF_FILL, False),
        ("note", (170, 750, 1260, 60),
         "Isolation invariant: target-facing drivers are high-Z during FT2232H power-up UART mode, whenever VREF is invalid, and until OpenOCD asserts ADBUS6 TARGET_EN.\nOpenOCD layout_init=0x0078/0x007b; U4/U5 VCC isolation and Ioff provide the secondary no-back-power barrier.",
         NOTE_FILL, False),
    ]

    for name, bounds, text_value, fill, bold in nodes:
        graphics.append(shape(graphic_id, name, bounds, text_value, fill,
                              None, bold))
        graphic_id += 1

    graphic_id = route(graphics, graphic_id, "usb-data-to-esd",
                       [(220, 330), (270, 330)], "right")
    graphic_id = route(graphics, graphic_id, "esd-to-ftdi",
                       [(460, 330), (590, 330)], "right")
    graphic_id = route(graphics, graphic_id, "usb-power-to-ldo",
                       [(130, 280), (130, 130), (270, 130)], "right")
    graphic_id = route(graphics, graphic_id, "ldo-to-ftdi",
                       [(480, 130), (540, 130), (540, 260), (590, 260)],
                       "right")
    graphic_id = route(graphics, graphic_id, "clock-to-ftdi",
                       [(685, 160), (685, 220)], "down")
    graphic_id = route(graphics, graphic_id, "eeprom-to-ftdi",
                       [(870, 115), (840, 115), (840, 220)], "down")
    graphic_id = route(graphics, graphic_id, "ftdi-to-output-translator",
                       [(870, 280), (990, 280)], "right")
    graphic_id = route(graphics, graphic_id, "input-translator-to-ftdi",
                       [(700, 500), (700, 420)], "up")
    graphic_id = route(graphics, graphic_id, "vref-to-comparator",
                       [(220, 620), (270, 620)], "right")
    graphic_id = route(graphics, graphic_id, "comparator-to-gate",
                       [(480, 620), (520, 620), (520, 700), (900, 700)],
                       "right")
    graphic_id = route(graphics, graphic_id, "target-enable-to-gate",
                       [(590, 400), (540, 400), (540, 660), (900, 660)],
                       "right")
    graphic_id = route(graphics, graphic_id, "outputs-to-target",
                       [(1220, 310), (1330, 310)], "right")
    route(graphics, graphic_id, "target-to-inputs",
          [(1330, 500), (1280, 500), (1280, 560), (820, 560)], "left")

    document["CanvasSize"] = "{1600, 830}"
    document["BackgroundGraphic"]["Bounds"] = "{{0, 0}, {1600, 830}}"
    document["HPages"] = 1
    document["VPages"] = 1
    document["GraphicsList"] = graphics

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("wb") as stream:
        plistlib.dump(document, stream, fmt=plistlib.FMT_XML, sort_keys=False)


if __name__ == "__main__":
    main()
