#!/usr/bin/env python3
"""Static consistency checks for the wasp1 FT2232H debugger collateral."""

from __future__ import annotations

from pathlib import Path
import csv
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


def read_rel(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require_file(path: str) -> Path:
    file_path = ROOT / path
    if not file_path.is_file():
        raise AssertionError(f"missing file: {path}")
    return file_path


def require_token(text: str, token: str, label: str) -> None:
    if token not in text:
        raise AssertionError(f"{label}: missing token {token!r}")


def require_regex(text: str, pattern: str, label: str) -> None:
    if not re.search(pattern, text, flags=re.MULTILINE):
        raise AssertionError(f"{label}: pattern not found: {pattern}")


def check_openocd_cfg() -> None:
    cfg = read_rel("openocd/wasp1_ft2232h_reference.cfg")
    required_tokens = [
        "adapter driver ftdi",
        "ftdi vid_pid 0x0403 0x6010",
        "ftdi channel 0",
        "ftdi layout_init 0x0078 0x007b",
        "ftdi layout_signal nTRST -data 0x0010 -oe 0x0010",
        "ftdi layout_signal nSRST -data 0x0020 -oe 0x0020",
        "transport select jtag",
        "adapter speed 1000",
        "reset_config trst_and_srst separate",
        "jtag newtap $_CHIPNAME cpu -irlen 5 -expected-id 0x100001cf",
        "target create $_TARGETNAME riscv -chain-position $_CHIPNAME.cpu",
    ]
    for token in required_tokens:
        require_token(cfg, token, "openocd cfg")
    print("PASS openocd reference cfg")


def check_pinout_doc() -> None:
    pinout = read_rel("docs/ftdi_debugger_pinout.md")
    for token in [
        "ADBUS0",
        "ADBUS1",
        "ADBUS2",
        "ADBUS3",
        "ADBUS4",
        "ADBUS5",
        "BDBUS0",
        "BDBUS1",
        "ADBUS6",
        "TARGET_EN",
        "`0x0078`",
        "`0x007b`",
        "`0x0010`",
        "`0x0020`",
        "OpenOCD TAP IDCODE 0x100001cf",
        "GDB native stepi",
        "GDB hbreak at 0x4",
    ]:
        require_token(pinout, token, "pinout doc")
    require_regex(pinout, r"1\.8 V <= VREF <= 3\.3 V", "pinout doc")
    print("PASS pinout document")


def check_spec_and_plan() -> None:
    spec = read_rel("docs/ftdi_debugger_spec.md")
    plan = read_rel("docs/ftdi_debugger_design_plan.md")
    design = read_rel("docs/ftdi_debugger_revA_design_spec.md")
    verify = read_rel("docs/ftdi_debugger_verification_plan.md")
    for token in [
        "FT2232H",
        "Channel A",
        "MPSSE",
        "Channel B",
        "UART",
        "0x100001cf",
    ]:
        require_token(spec, token, "spec")
    for token in [
        "Freeze connector pinout",
        "OpenOCD FTDI config",
        "GDB bring-up",
    ]:
        require_token(plan, token, "design plan")
    for token in [
        "FT2232HL",
        "SN74AXC8T245",
        "SN74AXC2T245",
        "TLV7041",
        "SHIFT_OE_N = !(VREF_VALID && FT_TARGET_EN)",
        "layout_init 0x0078 0x007b",
    ]:
        require_token(design, token, "Rev A design spec")
    for token in [
        "USB enumeration",
        "TAP scan",
        "DTM/DM discovery",
        "GDB attach",
        "UART channel",
    ]:
        require_token(verify, token, "verification plan")
    print("PASS spec and plans")


def read_csv_rel(path: str) -> list[dict[str, str]]:
    with (ROOT / path).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def find_row(rows: list[dict[str, str]], key: str, value: str) -> dict[str, str]:
    for row in rows:
        if row.get(key) == value:
            return row
    raise AssertionError(f"csv: missing row with {key}={value!r}")


def check_hardware_package() -> None:
    schematic = read_rel("hw/schematic/wasp1_ft2232h_debugger_revA_schematic.md")
    nets = read_csv_rel("hw/netlist/wasp1_ft2232h_debugger_revA_nets.csv")
    bom = read_csv_rel("hw/bom/wasp1_ft2232h_debugger_revA_bom.csv")

    for token in [
        "USB and local power",
        "FT2232H core",
        "VREF detection and level shifting",
        "Target connector ESD and test access",
        "ADBUS0",
        "ADBUS5",
        "BDBUS0",
        "BDBUS1",
        "ftdi layout_init 0x0078 0x007b",
        "TARGET_EN",
        "SHIFT_OE_N",
        "VREF_VALID",
    ]:
        require_token(schematic, token, "hardware schematic input")

    required_nets = {
        "FT_A_TCK": ("U1 ADBUS0", "U4 A1", "0x0001"),
        "FT_A_TDI": ("U1 ADBUS1", "U4 A2", "0x0002"),
        "FT_A_TDO": ("U5 A1", "U1 ADBUS2", "0x0004"),
        "FT_A_TMS": ("U1 ADBUS3", "U4 A3", "0x0008"),
        "FT_A_NTRST": ("U1 ADBUS4", "U4 A4", "0x0010"),
        "FT_A_NSRST": ("U1 ADBUS5", "U4 A5", "0x0020"),
        "FT_TARGET_EN": ("U1 ADBUS6", "U7 input B", "0x0040"),
        "FT_B_TXD": ("U1 BDBUS0", "U4 A6", "Channel B"),
        "FT_B_RXD": ("U5 A2", "U1 BDBUS1", "Channel B"),
        "VREF_VALID": ("U3 output", "U7 input A and Q1 gate", "1.57 V"),
        "SHIFT_OE_N": ("U7 output", "U4 OE_N/U5 OE_N", "both high"),
    }
    for net, (source, destination, token) in required_nets.items():
        row = find_row(nets, "net", net)
        if row.get("source") != source or row.get("destination") != destination:
            raise AssertionError(
                f"netlist: {net} expected {source}->{destination}, "
                f"observed {row.get('source')}->{row.get('destination')}"
            )
        require_token(row.get("requirement", ""), token, f"netlist {net}")

    for refdes in [
        "J1", "U1", "Y1", "U2", "U3", "U4", "U5", "U6", "U7",
        "ESD1", "ESD2", "J2", "Q1", "RLED1", "RLED2", "RVALID",
        "RRESET", "REECS", "RU4_A7/RU4_A8", "CDEC1-CDEC10", "TP1-TP8",
    ]:
        find_row(bom, "refdes", refdes)
    require_token(
        find_row(bom, "refdes", "U1").get("preferred_part_or_class", ""),
        "FT2232H",
        "bom U1",
    )
    require_token(
        find_row(bom, "refdes", "U4").get("preferred_part_or_class", ""),
        "SN74AXC8T245",
        "bom U4",
    )
    require_token(
        find_row(bom, "refdes", "U7").get("preferred_part_or_class", ""),
        "SN74LVC1G00",
        "bom U7",
    )
    require_token(
        find_row(bom, "refdes", "J2").get("notes", ""),
        "VREF/JTAG/reset/UART/GND",
        "bom J2",
    )
    print("PASS hardware package")


def check_manufacturing_docs() -> None:
    """Check release notes that gate generated fabrication outputs."""
    fabrication = read_rel(
        "hw/fabrication/wasp1_ft2232h_debugger_revA_fabrication_notes.md"
    )
    assembly = read_rel(
        "hw/assembly/wasp1_ft2232h_debugger_revA_assembly_notes.md"
    )
    for token in [
        "110 mm x 65 mm",
        "ENIG",
        "90 ohm nominal",
        "Gerber X2",
        "IPC-D-356",
        "J1/J2 board-local footprint warnings",
    ]:
        require_token(fabrication, token, "fabrication notes")
    for token in [
        "U2 is DNP",
        "J1: shell opening faces the left board edge",
        "VREF to VCC_3V3: open circuit",
        "SHIFT_OE_N",
        "FT_TARGET_EN",
    ]:
        require_token(assembly, token, "assembly notes")
    print("PASS manufacturing documentation")


def check_native_kicad_schematic() -> None:
    base = "hw/kicad/wasp1_ft2232h_debugger_revA"
    expected_files = [
        "wasp1_ft2232h_debugger_revA.kicad_sch",
        "wasp1_ft2232h_debugger_revA.kicad_sym",
        "wasp1_ft2232h_debugger_revA.kicad_pro",
        "sym-lib-table",
        "fp-lib-table",
        "01_usb_power.kicad_sch",
        "02_ft2232h_core.kicad_sch",
        "03_vref_level_shift.kicad_sch",
        "04_target_io.kicad_sch",
    ]
    for name in expected_files:
        require_file(f"{base}/{name}")

    combined = "\n".join(
        read_rel(f"{base}/{name}")
        for name in expected_files
        if name.endswith(".kicad_sch")
    )
    for token in [
        'property "Reference" "U1"',
        'property "Reference" "U4"',
        'property "Reference" "Q1"',
        'property "Reference" "TP8"',
        'VREF_VALID',
        'SHIFT_OE_N',
        'U4_A7_UNUSED',
        'U4_A8_UNUSED',
        'WASP1 TARGET',
    ]:
        require_token(combined, token, "native KiCad schematic")
    print("PASS native KiCad schematic structure")


def check_native_kicad_board() -> None:
    """Check that the committed native PCB includes the routed Rev A structure."""
    base = "hw/kicad/wasp1_ft2232h_debugger_revA"
    board = read_rel(f"{base}/wasp1_ft2232h_debugger_revA.kicad_pcb")
    rules = read_rel(f"{base}/wasp1_ft2232h_debugger_revA.kicad_dru")
    project = read_rel(f"{base}/wasp1_ft2232h_debugger_revA.kicad_pro")
    require_regex(board, r'\(general\s+\(thickness 1\.6\)', "native KiCad PCB")
    for pattern in [
        r'\(\d+ "In1\.Cu" power\)',
        r'\(\d+ "In2\.Cu" power\)',
    ]:
        require_regex(board, pattern, "native KiCad PCB")
    for token in [
        'property "Reference" "J1"',
        'property "Reference" "J2"',
        'property "Reference" "U1"',
        'property "Reference" "TP8"',
        '(attr smd dnp)',
        'wasp1 FT2232H DEBUGGER REV A',
        'GND_PLANE_IN1',
        '(segment',
        '(via',
    ]:
        require_token(board, token, "native KiCad PCB")
    require_regex(
        board,
        r'\(property "Datasheet"[\s\S]*?\(hide yes\)',
        "native KiCad PCB hidden fabrication properties",
    )
    for token in [
        'USB differential pair skew',
        'Local low-voltage power minimum width',
        'USB VBUS minimum width',
        'UQFN fine-pitch pad clearance',
        'USB-C manufacturer footprint hole clearance',
        'U5 local fanout clearance',
        'USB-C local signal fanout clearance',
    ]:
        require_token(rules, token, "native KiCad PCB rules")
    for token in [
        '"name": "USB_DIFF"',
        '"name": "POWER"',
        '"name": "VBUS"',
        '"name": "JTAG"',
    ]:
        require_token(project, token, "native KiCad PCB net classes")
    print("PASS native KiCad routed PCB structure")


def main() -> int:
    try:
        check_openocd_cfg()
        check_pinout_doc()
        check_spec_and_plan()
        check_hardware_package()
        check_manufacturing_docs()
        check_native_kicad_schematic()
        check_native_kicad_board()
    except AssertionError as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    print("RESULT PASS ftdi_debugger collateral check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
