# uart_baud Spec

## 1. Purpose

`uart_baud` generates a periodic baud tick for UART TX/RX logic.

## 2. Requirements

When disabled, the tick output must remain low and the internal count must
restart from zero.

When enabled, the module must emit a one-cycle tick every divisor cycles. A
zero divisor must be treated as divisor one.

## 3. Verification Requirements

Verification through `ahb_uart` must cover configured divisor behavior in the
TX/RX loopback path.
