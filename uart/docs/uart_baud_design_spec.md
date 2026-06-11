# uart_baud Design Spec

## 1. Scope

`uart_baud` is a small reload-style baud tick generator used by UART TX and RX.

## 2. Block Diagram

```text
 clk_i / rst_ni
      |
      v
 +-------------+
 | count_q     |<--- enable_i
 +------+------+     divisor_i
        |
        v
 +-------------+
 | compare     |---- tick_o
 | count == N  |
 +-------------+
```

## 3. Design

The counter starts from zero. While enabled, it increments every cycle until it
reaches `terminal_count - 1`. On that cycle, `tick_o` pulses for one cycle and
the counter returns to zero.

`divisor_i == 0` is mapped to one so the generator never creates an invalid
terminal count.

## 4. Reset

Reset clears the counter and deasserts `tick_o`.
