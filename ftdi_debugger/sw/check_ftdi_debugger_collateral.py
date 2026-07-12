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
        "VREF and level shifting",
        "Target connector and indicators",
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
        "VREF_VALID": ("U3 output", "U7 input A", "1.57 V"),
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
        "ESD1", "ESD2", "J2",
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


def main() -> int:
    try:
        check_openocd_cfg()
        check_pinout_doc()
        check_spec_and_plan()
        check_hardware_package()
    except AssertionError as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    print("RESULT PASS ftdi_debugger collateral check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
