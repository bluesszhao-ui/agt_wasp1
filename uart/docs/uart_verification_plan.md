# uart Verification Plan

## 1. Goals

Verify `ahb_uart` as a minimal 8N1 UART peripheral for software bring-up and
OTP programming transport.

The first milestone focuses on AHB-Lite register behavior, TX/RX serial
loopback, FIFO behavior, interrupt behavior, error handling, and target macro
compile coverage.

## 2. Case Table

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

## 3. Target Compile Matrix

| Target | Macro | Command | Expected result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C uart lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C uart lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C uart lint-fpga-v7` | PASS |

## 4. Coverage Intent

```text
register read path
register write path
TX FIFO push path
TX FIFO full path
RX FIFO pop path
serial TX/RX loopback
TX empty IRQ path
RX available IRQ path
RX overrun path
W1C clear path
AHB error paths
deterministic random loopback
```
