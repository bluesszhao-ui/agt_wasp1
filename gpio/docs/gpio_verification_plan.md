# gpio Verification Plan

## 1. Goals

Verify `ahb_gpio` as a 32-bit GPIO peripheral and interrupt source.

The first milestone focuses on AHB-Lite register behavior, GPIO input/output
behavior, direction control, interrupt generation, error handling, and target
macro compile coverage.

## 2. Case Table

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

## 3. Target Compile Matrix

| Target | Macro | Command | Expected result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C gpio lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C gpio lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C gpio lint-fpga-v7` | PASS |

## 4. Coverage Intent

```text
register read path
register write path
input sync path
output data path
direction path
set/clear/toggle helpers
level IRQ path
edge IRQ path
IRQ mask path
W1C status clear path
AHB error paths
deterministic random output checks
```
