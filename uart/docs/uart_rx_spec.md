# uart_rx Spec

## 1. Purpose

`uart_rx` receives one 8N1 UART frame and presents the received byte.

## 2. Requirements

The receiver must detect a low start bit, sample 8 data bits LSB first, and
require a high stop bit.

On a valid frame, it must assert `data_valid_o` for one cycle with the received
byte.

On an invalid stop bit, it must assert `frame_error_o` for one cycle.

When disabled, RX must return to idle state.

## 3. Verification Requirements

Verification through `ahb_uart` must cover valid receive through loopback and
RX available/overrun behavior.
