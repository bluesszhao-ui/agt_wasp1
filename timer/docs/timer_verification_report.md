# timer Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-11 |
| Tool | Verilator 5.046 |
| Lint command | `make -C timer lint` |
| IC lint command | `make -C timer lint-ic` |
| FPGA lint command | `make -C timer lint-fpga-v7` |
| Simulation command | `make -C timer sim` |
| Lint result | PASS |
| Target lint result | PASS for generic, IC, and Xilinx Virtex-7 FPGA macro builds |
| Simulation result | PASS |
| Self-check count | 65 |
| Lint log | `timer/logs/lint.log` |
| Simulation log | `timer/logs/tb_ahb_timer.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, HRDATA zero, IRQ low | PASS |
| Directed | Read reset registers | CTRL zero, STATUS zero, CMP all ones | PASS |
| Directed | Write mtime while disabled and wait | mtime remains stable | PASS |
| Directed | Enable counter and IRQ with cmp in future | IRQ low before compare, high after compare | PASS |
| Directed | Move cmp to future | IRQ deasserts and STATUS pending clears | PASS |
| Directed | Keep pending true with irq disabled | STATUS pending set, IRQ low | PASS |
| Directed | Re-enable irq when pending | IRQ asserts | PASS |
| Directed | Misaligned, halfword, unknown register, out-of-range accesses | HRESP ERROR | PASS |
| Random | 4 deterministic mtime/cmp deltas | IRQ asserts after programmed delta | PASS |

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 65 |
| Register checks | 49 |
| Counter behavior checks | 3 |
| IRQ checks | 9 |
| Error checks | 5 |
| Deterministic random compare tests | 4 |

## 5. Target Compile Matrix

| Target | Macro | Command | Result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C timer lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C timer lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C timer lint-fpga-v7` | PASS |
