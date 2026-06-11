# intc Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-11 |
| Tool | Verilator 5.046 |
| Lint command | `make -C intc lint` |
| IC lint command | `make -C intc lint-ic` |
| FPGA lint command | `make -C intc lint-fpga-v7` |
| Simulation command | `make -C intc sim` |
| Lint result | PASS |
| Target lint result | PASS for generic, IC, and Xilinx Virtex-7 FPGA macro builds |
| Simulation result | PASS |
| Self-check count | 64 |
| Lint log | `intc/logs/lint.log` |
| Simulation log | `intc/logs/tb_ahb_intc.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, MEIP low, claim ID zero | PASS |
| Directed | Read reset registers | Pending/enable/threshold clear, source priorities initialized | PASS |
| Directed | Drive IRQ2 while disabled | Pending captures, MEIP remains low | PASS |
| Directed | Enable IRQ2 | MEIP asserts, claim returns 2 | PASS |
| Directed | Complete IRQ2 | Pending clears after source drops | PASS |
| Directed | Configure priorities for IRQ2/4/5 | Highest priority source is claimed | PASS |
| Directed | Raise threshold | Sources at or below threshold are masked | PASS |
| Directed | Equal priority IRQ1/3 | Lower source ID wins | PASS |
| Directed | Source ID0 activity | ID0 is ignored | PASS |
| Directed | W1C pending clear | Selected pending bit clears | PASS |
| Random | 8 deterministic source combinations | Claim returns expected lowest enabled pending source | PASS |
| Directed | Misaligned, byte, unknown, invalid priority, out-of-range accesses | HRESP ERROR | PASS |

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 64 |
| Register checks | 56 |
| Pending checks | 2 |
| Claim checks | 2 |
| Threshold checks | 1 |
| Priority checks | 1 |
| Error checks | 5 |
| Deterministic random source checks | 8 |

## 5. Target Compile Matrix

| Target | Macro | Command | Result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C intc lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C intc lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C intc lint-fpga-v7` | PASS |
