# wdg Verification Plan

## 1. Goals

Verify `ahb_wdg` register behavior, timeout behavior, kick handling, IRQ/reset
outputs, AHB error responses, deterministic random timeout coverage, and target
macro lint.

## 2. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, HRDATA zero, IRQ/reset low | PASS |
| Directed | Read reset registers | CTRL zero, STATUS zero, TIMEOUT `0x0000_FFFF`, COUNT zero | PASS |
| Directed | Program timeout 4 and enable IRQ/reset | CTRL reads back enable, IRQ enable, reset enable | PASS |
| Directed | Wait 4 enabled cycles | Expired status set, IRQ high, reset request high | PASS |
| Directed | Write valid KICK key | Count restarts, expired/reset request clear | PASS |
| Directed | Kick before timeout | IRQ/reset remain low | PASS |
| Directed | Write bad KICK key | Key error latches and watchdog is not fed | PASS |
| Directed | Write CTRL.clear | Count/status/output state clears | PASS |
| Directed | Enable reset only with IRQ masked | Reset request asserts, IRQ remains low | PASS |
| Directed | Misaligned, halfword, unknown register, out-of-range accesses | HRESP ERROR | PASS |
| Random | 4 deterministic timeout values from 2 to 8 | IRQ asserts after programmed timeout | PASS |

## 3. Target Compile Matrix

| Target | Macro | Command | Expected result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C wdg lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C wdg lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C wdg lint-fpga-v7` | PASS |

## 4. Coverage Intent

```text
reset state
register read path
register write path
enabled watchdog count path
timeout expired path
IRQ mask path
reset request path
valid kick path
bad key path
clear path
AHB error paths
deterministic random timeout tests
```
