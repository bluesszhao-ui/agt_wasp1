# uart_rx Design Spec

## 1. Scope

`uart_rx` receives one 8N1 UART frame and emits a one-cycle valid pulse with
the received byte.

## 2. Block Diagram

```text
 uart_rx_i
    |
    v
 +----------+    baud_tick_i    +----------+
 | RX_IDLE  |------------------>| RX_START |
 +----------+                   +----+-----+
                                     |
                                     v
                                +----------+
                                | RX_DATA  |
                                | bit_idx  |
                                +----+-----+
                                     |
                                     v
                                +----------+
                                | RX_STOP  |--> data_valid_o/frame_error_o
                                +----------+
```

## 3. FSM

`RX_IDLE` waits for a low start bit.

`RX_START` waits one baud tick and confirms the line is still low before data
sampling begins.

`RX_DATA` samples eight data bits on baud ticks and stores them LSB first.

`RX_STOP` samples the stop bit. A high stop bit produces `data_valid_o`; a low
stop bit produces `frame_error_o`.

## 4. Reset and Disable

Reset or disable returns the FSM to `RX_IDLE` and clears transient outputs.
