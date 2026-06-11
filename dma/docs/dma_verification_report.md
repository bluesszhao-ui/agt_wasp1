# dma Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-11 |
| Tool | Verilator 5.046 |
| Lint command | `make -C dma lint` |
| IC lint command | `make -C dma lint-ic` |
| FPGA lint command | `make -C dma lint-fpga-v7` |
| Simulation command | `make -C dma sim` |
| Lint result | PASS |
| Target lint result | PASS for generic, IC, and Xilinx Virtex-7 FPGA macro builds |
| Simulation result | PASS |
| Self-check count | 64 |
| Lint log | `dma/logs/lint.log` |
| Simulation log | `dma/logs/tb_ahb_dma.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | Slave OKAY, master idle, IRQ low, status clear | PASS |
| Directed | Read reset status | busy/done/error clear | PASS |
| Directed | Program SRC/DST/LEN and start 4-word copy | Destination words match source words | PASS |
| Random | 4 deterministic copy cases | Destination words match source words | PASS |
| Directed | Complete with IRQ enabled | `dma_irq_o` asserts on done | PASS |
| Directed | Clear status | done/error clear | PASS |
| Directed | Start with LEN zero | STATUS.error set | PASS |
| Directed | Start with misaligned source | STATUS.error set | PASS |
| Directed | Inject master read error | STATUS.error set | PASS |
| Directed | Inject master write error | STATUS.error set | PASS |
| Directed | Misaligned, byte, unknown register accesses | HRESP ERROR | PASS |

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 64 |
| Register checks | 46 |
| Copy checks | 5 |
| IRQ checks | 5 |
| Slave error checks | 3 |
| Deterministic random copy checks | 4 |
| Master read transfers | 15 |
| Master write transfers | 14 |

## 5. Target Compile Matrix

| Target | Macro | Command | Result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C dma lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C dma lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C dma lint-fpga-v7` | PASS |
