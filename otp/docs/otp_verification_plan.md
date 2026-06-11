# otp Verification Plan

## 1. Goals

Verify `ahb_otp` as the executable OTP storage block and programming control
slave.

The first milestone focuses on AHB-Lite access behavior, OTP programming
semantics, register behavior, lock behavior, and target macro compile coverage.

## 2. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, HRDATA zero, status clear | PASS |
| Directed | Read erased OTP data words | Data returns all ones | PASS |
| Directed | Attempt direct write to data window | HRESP ERROR and data remains unchanged | PASS |
| Directed | Write unlock key | KEY readback indicates unlocked | PASS |
| Directed | Program word from all ones to `F0F0_F0F0` | STATUS.done set and readback matches | PASS |
| Directed | Program same word to lower value `00F0_00F0` | Additional 1 -> 0 transition accepted | PASS |
| Directed | Attempt 0 -> 1 programming | STATUS.error set and data unchanged | PASS |
| Directed | Clear status | done/error clear | PASS |
| Directed | Program without valid key | STATUS.error set | PASS |
| Directed | Program out-of-range word address | STATUS.error set | PASS |
| Directed | Misaligned, unknown-register, out-of-range AHB accesses | HRESP ERROR | PASS |
| Random | 4 deterministic program/readback pairs | Readback matches programmed data | PASS |
| Directed | Lock OTP and attempt programming | locked status set, programming rejected | PASS |

## 3. Target Compile Matrix

| Target | Macro | Command | Expected result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C otp lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C otp lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C otp lint-fpga-v7` | PASS |

## 4. Coverage Intent

```text
data read path
register read/write path
program success path
program error path
status clear path
lock path
misaligned access errors
out-of-range errors
unknown register errors
deterministic random programming
```
