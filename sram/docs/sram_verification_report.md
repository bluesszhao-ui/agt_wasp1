# sram Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-11 |
| Tool | Verilator 5.046 |
| Lint command | `make -C sram lint` |
| Simulation command | `make -C sram sim` |
| Lint result | PASS |
| Simulation result | PASS |
| Target lint result | PASS for generic, IC, and Xilinx Virtex-7 FPGA macro builds |
| Self-check count | 52 |
| Lint log | `sram/logs/lint.log` |
| Simulation log | `sram/logs/tb_ahb_sram.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, HRDATA zero | PASS |
| Directed | Word write/read | Full 32-bit word is preserved | PASS |
| Directed | Halfword write to address offset 2 | Upper halfword updates, lower halfword preserved | PASS |
| Directed | Byte writes to lanes 0/1/2/3 | Only selected byte lane updates | PASS |
| Directed | Unselected NONSEQ write attempt | Existing word remains unchanged | PASS |
| Directed | Misaligned halfword write | HRESP ERROR | PASS |
| Directed | Misaligned word read | HRESP ERROR | PASS |
| Directed | Out-of-range high write | HRESP ERROR | PASS |
| Directed | Below-base read | HRESP ERROR | PASS |
| Random | 16 deterministic word write/read pairs | Read data matches written data | PASS |

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 52 |
| Word transfer count | 19 |
| Halfword transfer count | 2 |
| Byte transfer count | 4 |
| Error response count | 4 |
| Idle/unselected count | 1 |
| Deterministic random accesses | 16 |

## 5. Target Compile Matrix

| Target | Macro | Command | Result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C sram lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C sram lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C sram lint-fpga-v7` | PASS |
