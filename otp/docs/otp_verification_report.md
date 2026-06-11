# otp Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-11 |
| Tool | Verilator 5.046 |
| Lint command | `make -C otp lint` |
| IC lint command | `make -C otp lint-ic` |
| FPGA lint command | `make -C otp lint-fpga-v7` |
| Simulation command | `make -C otp sim` |
| Lint result | PASS |
| Target lint result | PASS for generic, IC, and Xilinx Virtex-7 FPGA macro builds |
| Simulation result | PASS |
| Self-check count | 84 |
| Lint log | `otp/logs/lint.log` |
| Simulation log | `otp/logs/tb_ahb_otp.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Case Table

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

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 84 |
| Data read checks | 6 |
| Register checks | 67 |
| Successful program operations | 6 |
| Error checks | 10 |
| Lock checks | 1 |
| Deterministic random program/readbacks | 4 |

## 5. Target Compile Matrix

| Target | Macro | Command | Result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C otp lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C otp lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C otp lint-fpga-v7` | PASS |
