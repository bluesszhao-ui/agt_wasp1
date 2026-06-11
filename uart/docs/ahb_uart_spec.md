# ahb_uart Spec

## 1. Purpose

`ahb_uart` provides the software-visible UART peripheral for bring-up and OTP
programming transport.

## 2. Serial Requirements

The UART must support:

```text
8 data bits
no parity
1 stop bit
LSB first
configurable baud divisor
```

## 3. Register Requirements

The UART must expose:

```text
DATA
STATUS
CTRL
BAUD
IRQ_STATUS
```

Writing `DATA` pushes a TX byte. Reading `DATA` pops an RX byte.

## 4. FIFO Requirements

The UART must provide TX and RX FIFOs. Writing `DATA` when the TX FIFO is full
must return ERROR.

RX overrun must be sticky until software clears the overrun IRQ status bit.

## 5. Interrupt Requirements

Interrupt status must support:

```text
TX empty
RX available
RX overrun
```

Interrupt status bits are W1C and may assert `uart_irq_o` only when their
corresponding enable bit is set.

## 6. Error Requirements

Only aligned word register accesses are supported. Misaligned, non-word,
out-of-range, unknown register, and TX-full DATA writes must return ERROR.

## 7. Verification Requirements

Verification must cover register access, TX/RX serial loopback, FIFO full, RX
overrun, IRQ status/W1C, error accesses, and deterministic random bytes.
