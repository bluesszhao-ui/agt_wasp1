# uart_tx Spec

## 1. Purpose

`uart_tx` serializes one byte into an 8N1 UART frame.

## 2. Requirements

The TX line must idle high.

For each accepted byte, the transmitter must emit:

```text
start bit = 0
8 data bits, LSB first
stop bit = 1
```

`data_ready_o` may assert only when enabled and not busy.

When disabled, TX must return to idle high and stop accepting bytes.

## 3. Verification Requirements

Verification through `ahb_uart` must cover TX byte acceptance, serial loopback,
busy behavior, and TX empty behavior.
