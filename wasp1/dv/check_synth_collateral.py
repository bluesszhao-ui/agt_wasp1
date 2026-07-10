#!/usr/bin/env python3
"""Static checks for wasp1 synthesis collateral.

The checker intentionally avoids running DC or Vivado. It verifies the contract
that ASIC synthesis sees SRAM/OTP blackboxes while the FPGA flow uses the normal
behavioral macro wrappers, and that both scripts constrain the SoC clocks.
"""

from pathlib import Path
import sys


WASP1_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = WASP1_DIR.parent


def read(path: Path) -> str:
    try:
      return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
      return path.read_text(encoding="latin-1")


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL {message}")
        raise SystemExit(1)
    print(f"PASS {message}")


def main() -> int:
    ic_filelist = read(WASP1_DIR / "filelists" / "wasp1_synth_ic.f")
    sim_filelist = read(WASP1_DIR / "filelists" / "wasp1.f")
    dc_tcl = read(WASP1_DIR / "dc" / "wasp1_ic_dc.tcl")
    vivado_tcl = read(WASP1_DIR / "dc" / "wasp1_v7_vivado.tcl")
    sdc = read(WASP1_DIR / "dc" / "wasp1_ic_constraints.sdc")
    xdc = read(WASP1_DIR / "dc" / "wasp1_v7_constraints.xdc")
    macro_doc = read(REPO_ROOT / "docs" / "wasp1_memory_macro_replacement.md")

    require("../sram/dc/wasp1_sram_macro_blackbox.sv" in ic_filelist,
            "ASIC filelist uses SRAM blackbox")
    require("../otp/dc/wasp1_otp_macro_blackbox.sv" in ic_filelist,
            "ASIC filelist uses OTP blackbox")
    require("../sram/rtl/wasp1_sram_macro.sv" not in ic_filelist,
            "ASIC filelist excludes behavioral SRAM macro")
    require("../otp/rtl/wasp1_otp_macro.sv" not in ic_filelist,
            "ASIC filelist excludes behavioral OTP macro")
    require("../sram/rtl/wasp1_sram_macro.sv" in sim_filelist,
            "normal SoC filelist keeps behavioral SRAM macro")
    require("../otp/rtl/wasp1_otp_macro.sv" in sim_filelist,
            "normal SoC filelist keeps behavioral OTP macro")

    require("WASP1_TARGET_IC" in dc_tcl, "DC script defines IC target macro")
    require("WASP1_TARGET_FPGA_XILINX_VIRTEX7" in vivado_tcl,
            "Vivado script defines Virtex-7 target macro")
    require("wasp1_synth_ic.f" in dc_tcl, "DC script reads ASIC synthesis filelist")
    require("filelists wasp1.f" in vivado_tcl, "Vivado script reads normal SoC filelist")

    for clock_name, text, label in (
        ("hclk_i", sdc, "ASIC SDC"),
        ("jtag_tck_i", sdc, "ASIC SDC"),
        ("hclk_i", xdc, "Virtex-7 XDC"),
        ("jtag_tck_i", xdc, "Virtex-7 XDC"),
    ):
        require(clock_name in text and "create_clock" in text,
                f"{label} constrains {clock_name}")

    require("about 45k-75k gates" in macro_doc,
            "memory macro policy records standard-cell gate-count estimate")
    require("about 1.5Mbit" in macro_doc,
            "memory macro policy records large-memory capacity")

    print("RESULT PASS wasp1 synthesis collateral static check")
    return 0


if __name__ == "__main__":
    sys.exit(main())
