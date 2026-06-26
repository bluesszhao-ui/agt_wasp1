# wasp1 Verification Report

## 1. Commands

```text
make -C wasp1 lint
make -C wasp1 lint-ic
make -C wasp1 lint-fpga-v7
make -C wasp1 sim
```

## 2. Results

| Check | Result |
| --- | --- |
| Generic lint | PASS |
| IC-target lint | PASS |
| Virtex-7-target lint | PASS |
| `tb_wasp1` simulation | PASS |

Simulation output:

```text
tb_wasp1 PASS pass_count=5 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0
```

## 3. Time-Sequenced Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-40ns | Hold reset active for four 10ns cycles | Integrated state resets; IO defaults are benign | PASS |
| 41ns | Check reset outputs | UART TX idle high, I2C drive enables low, GPIO output/enables zero, WDG reset low | PASS |
| 45ns-55ns | Release reset and allow one clock | SoC exits reset without unknown top-level control behavior | PASS |
| 55ns-95ns | Wait for core AHB master transfer | Core-side bridge/fabric path observes valid transfer | PASS |
| 95ns-105ns | Wait for debug status | Core debug status reports running or halted | PASS |
| 105ns-276ns | Continue idle peripheral window | WDG reset remains low; I2C drive enables remain low | PASS |

## 4. Residual Risk

This is an integration smoke test, not a full system software test. Remaining
top-level work includes integrated Debug Module/JTAG/OpenOCD flow, software
programming of OTP, end-to-end DMA memory-copy through real slave contents,
interrupt-driven software, and full SoC boot tests from `llvm_s1` output.
