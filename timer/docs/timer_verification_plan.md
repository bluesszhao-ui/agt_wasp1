# timer Verification Plan

## 1. Goals

Verify `ahb_timer` as the machine timer peripheral and interrupt source.

The first milestone focuses on AHB-Lite register behavior, 64-bit timer state,
interrupt compare behavior, error handling, and target macro compile coverage.

## 2. Case Table

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

## 3. Target Compile Matrix

| Target | Macro | Command | Expected result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C timer lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C timer lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C timer lint-fpga-v7` | PASS |

## 4. Coverage Intent

```text
register read path
register write path
counter enabled path
counter disabled path
compare pending path
IRQ mask path
pending clear path
AHB error paths
deterministic random compare tests
```
