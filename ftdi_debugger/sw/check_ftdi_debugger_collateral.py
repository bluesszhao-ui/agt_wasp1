#!/usr/bin/env python3
"""Static consistency checks for the wasp1 FT2232H debugger collateral."""

from __future__ import annotations

from pathlib import Path
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
        "ftdi layout_init 0x0038 0x003b",
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
        "`0x0038`",
        "`0x003b`",
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
        "USB enumeration",
        "TAP scan",
        "DTM/DM discovery",
        "GDB attach",
        "UART channel",
    ]:
        require_token(verify, token, "verification plan")
    print("PASS spec and plans")


def main() -> int:
    try:
        check_openocd_cfg()
        check_pinout_doc()
        check_spec_and_plan()
    except AssertionError as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    print("RESULT PASS ftdi_debugger collateral check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
