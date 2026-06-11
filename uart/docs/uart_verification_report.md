# uart Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-11 |
| Tool | Verilator 5.046 |
| Lint command | `make -C uart lint` |
| IC lint command | `make -C uart lint-ic` |
| FPGA lint command | `make -C uart lint-fpga-v7` |
| Simulation command | `make -C uart sim` |
| Lint result | PASS |
| Target lint result | PASS for generic, IC, and Xilinx Virtex-7 FPGA macro builds |
| Simulation result | PASS |
| Self-check count | 55 |
| Lint log | `uart/logs/lint.log` |
| Simulation log | `uart/logs/tb_ahb_uart.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, TX idle high, IRQ low | PASS |
| Directed | Read reset registers | TX empty and RX empty status are set, CTRL/IRQ clear | PASS |
| Directed | Program BAUD and CTRL | Register readback matches | PASS |
| Directed | Write TX byte and loop TX to RX | RX DATA readback matches transmitted byte | PASS |
| Random | 4 deterministic loopback bytes | RX DATA readback matches each byte | PASS |
| Directed | Fill TX FIFO while TX disabled | Full status set and next DATA write returns ERROR | PASS |
| Directed | Enable TX empty IRQ | IRQ asserts and status bit is readable/clearable | PASS |
| Directed | Receive loopback byte with RX IRQ enabled | RX available IRQ asserts and DATA readback matches | PASS |
| Directed | Receive more bytes than RX FIFO depth | RX overrun status and IRQ assert | PASS |
| Directed | Misaligned, byte, unknown register, out-of-range accesses | HRESP ERROR | PASS |

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 55 |
| Register checks | 18 |
| TX checks | 12 |
| RX checks | 12 |
| IRQ checks | 3 |
| Error checks | 6 |
| Deterministic random loopback checks | 4 |

## 5. Target Compile Matrix

| Target | Macro | Command | Result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C uart lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C uart lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C uart lint-fpga-v7` | PASS |
