# wasp1 Deterministic-Random IRQ Stress Specification

## 1. Purpose

This regression stresses interrupt entry/return and concurrent SoC activity
with a repeatable pseudo-random schedule. It complements the directed timer,
DMA, GPIO, UART, and mixed-interrupt firmware tests; it does not replace them.

## 2. Stimulus Contract

The OTP firmware shall start xorshift32 with seed `0x1a2b3c4d` and execute 12
rounds. The low two bits of each updated state select one operation:

| Selector | Operation | Expected interrupt events |
| ---: | --- | ---: |
| 0 | Arm the machine timer | 1 timer interrupt |
| 1 | Copy four D-SRAM words with DMA IRQ enabled | 1 DMA external interrupt |
| 2 | Request a testbench-driven GPIO[0] level-high pulse | 1 GPIO external interrupt |
| 3 | Arm timer and DMA together | 1 timer plus 1 DMA interrupt, in either order |

Each round shall complete before the next PRNG update. UART shall accept one
progress byte per round plus an initial marker so the run also exercises
uncached MMIO while interrupt traffic is active.

## 3. Firmware Result Contract

Firmware shall publish a D-SRAM mailbox at offset `0x3b00` containing:

```text
completion magic and done word
final PRNG state and packed selector trace
completed round and interrupt-event counts
timer, DMA, and GPIO interrupt counts
order-independent event checksum
DMA destination-data checksum
GPIO request and acknowledgement epochs
last mcause and last external claim ID
failure code and UART progress-byte count
```

The firmware shall stop with a nonzero failure code when an interrupt times
out, an unexpected trap/claim occurs, DMA reports an error, or copied data does
not match.

## 4. Independent Testbench Checks

The top-level testbench shall independently run the same xorshift32 recurrence
to derive the final state, selector trace, source counts, total event count,
event checksum, DMA checksum, and expected number of GPIO handshakes. It shall
drive GPIO[0] high only while the request epoch exceeds the acknowledgement
epoch and shall return the pin low after acknowledgement.

The case passes only when all mailbox values match, every final interrupt line
is deasserted, DMA done/error state is clear, timer IRQ is low, GPIO pending is
clear, and the observed UART FIFO pushes cover all 13 progress bytes.

## 5. Timing and Reproducibility

The verification clock is 100 MHz with `1ns/1ps` simulation resolution. The
seed and round count are fixed in the baseline regression so failures reproduce
exactly. Additional seeds may be added later as separate named regressions.
