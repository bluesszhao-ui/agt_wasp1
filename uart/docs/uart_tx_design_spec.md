# uart_tx Design Spec

## 1. Scope

`uart_tx` serializes one 8-bit data byte into an 8N1 UART frame.

## 2. Block Diagram

```text
 data_valid_i/data_i
        |
        v
 +-------------+
 | frame load  |  {stop, data[7:0], start}
 +------+------+
        |
        v
 +-------------+    baud_tick_i
 | shifter_q   |<----------------+
 +------+------+                 |
        |                        |
        v                        |
      tx_o                +------+------+
                          | bit_count_q |
                          +-------------+
```

## 3. Design

When enabled and idle, `data_valid_i` loads a 10-bit frame into the shifter:

```text
bit 0      start bit 0
bits 1-8   data bits LSB first
bit 9      stop bit 1
```

On each baud tick while busy, the low shifter bit is driven on `tx_o`, the
shifter shifts right, and the bit counter decrements.

`data_ready_o` is high only when the transmitter is enabled and not busy.

## 4. Reset and Disable

Reset or disable forces TX idle high and clears the busy counter.
