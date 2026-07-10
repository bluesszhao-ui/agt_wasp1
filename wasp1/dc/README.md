# wasp1 Synthesis Collateral

## 1. Scope

This directory contains first-pass synthesis collateral for the integrated
`wasp1` top.

It is deliberately split by implementation target:

| Target | Script | Constraint file | Memory treatment |
| --- | --- | --- | --- |
| ASIC / IC | `wasp1_ic_dc.tcl` | `wasp1_ic_constraints.sdc` | SRAM/OTP blackbox stubs |
| Xilinx Virtex-7 | `wasp1_v7_vivado.tcl` | `wasp1_v7_constraints.xdc` | Behavioral macro wrappers infer FPGA RAM |

## 2. ASIC Flow

The ASIC flow reads:

```text
wasp1/filelists/wasp1_synth_ic.f
```

That filelist replaces:

```text
sram/rtl/wasp1_sram_macro.sv -> sram/dc/wasp1_sram_macro_blackbox.sv
otp/rtl/wasp1_otp_macro.sv   -> otp/dc/wasp1_otp_macro_blackbox.sv
```

Required environment before running Design Compiler:

```sh
export WASP1_TARGET_LIBRARY="/path/to/stdcell_tt.db"
export WASP1_LINK_LIBRARY="/path/to/macro_timing.db"
dc_shell -f wasp1/dc/wasp1_ic_dc.tcl
```

The first ASIC output reports are written under:

```text
wasp1/logs/dc_ic/
```

Mapped netlist/checkpoints are written under:

```text
wasp1/build/dc_ic/
```

## 3. Virtex-7 Flow

The FPGA flow reads the normal SoC filelist:

```text
wasp1/filelists/wasp1.f
```

The default part is:

```text
xc7vx485tffg1761-2
```

Override it when a concrete board is selected:

```sh
export WASP1_VIVADO_PART=xc7vx690tffg1761-2
vivado -mode batch -source wasp1/dc/wasp1_v7_vivado.tcl
```

The XDC intentionally has no pin locations yet. Add board-specific PACKAGE_PIN
and IOSTANDARD constraints before implementation/bitstream work.

## 4. Static Check

Run:

```sh
make -C wasp1 synth-collateral-check
```

This check verifies the target split, memory macro blackbox usage, and clock
constraint presence without requiring commercial EDA tools.
