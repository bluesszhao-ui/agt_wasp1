# gpio Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-11 |
| Tool | Verilator 5.046 |
| Lint command | `make -C gpio lint` |
| IC lint command | `make -C gpio lint-ic` |
| FPGA lint command | `make -C gpio lint-fpga-v7` |
| Simulation command | `make -C gpio sim` |
| Lint result | PASS |
| Target lint result | PASS for generic, IC, and Xilinx Virtex-7 FPGA macro builds |
| Simulation result | PASS |
| Self-check count | 69 |
| Lint log | `gpio/logs/lint.log` |
| Simulation log | `gpio/logs/tb_ahb_gpio.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, HRDATA zero, outputs/oe zero, IRQ low | PASS |
| Directed | Read reset registers | OUT, DIR, IRQ_EN, IRQ_STATUS are zero | PASS |
| Directed | Write DATA_OUT and DIR | gpio_out_o and gpio_oe_o update | PASS |
| Directed | Use SET/CLR/TOGGLE | Output readback matches expected bit operations | PASS |
| Directed | Drive external input and wait for sync | DATA_IN readback matches synchronized input | PASS |
| Directed | Configure level-high IRQ | IRQ asserts when input is high | PASS |
| Directed | Clear level IRQ while input remains high | Status reasserts | PASS |
| Directed | Clear level IRQ after input goes low | IRQ deasserts | PASS |
| Directed | Configure rising/falling edge IRQs | Status captures selected edges | PASS |
| Directed | Mask IRQ | IRQ output deasserts | PASS |
| Directed | Misaligned, byte, unknown register, out-of-range accesses | HRESP ERROR | PASS |
| Random | 8 deterministic output/toggle/readback checks | Readback matches reference data | PASS |

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 69 |
| Register checks | 55 |
| Data path checks | 2 |
| IRQ checks | 9 |
| Error checks | 5 |
| Deterministic random output checks | 8 |

## 5. Target Compile Matrix

| Target | Macro | Command | Result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C gpio lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C gpio lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C gpio lint-fpga-v7` | PASS |
