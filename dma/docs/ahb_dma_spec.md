# ahb_dma Spec

## 1. Purpose

`ahb_dma` provides a single-channel DMA engine and the second AHB master in
wasp1.

## 2. Register Requirements

The DMA block must expose:

```text
SRC
DST
LEN
CTRL
STATUS
```

`LEN` is the transfer length in 32-bit words.

## 3. Transfer Requirements

The first implementation must support:

```text
single-channel memory-to-memory copy
word-aligned source and destination
word-sized transfers
one read followed by one write per word
single AHB transfers, no burst
```

## 4. Status and IRQ Requirements

`STATUS` must expose busy, done, and error.

`done` and `error` must be sticky until cleared by software. `dma_irq_o` must
assert when IRQ is enabled and done or error is set.

## 5. Error Requirements

The DMA must report error status for:

```text
zero length start
misaligned source or destination
start while busy
AHB master read HRESP ERROR
AHB master write HRESP ERROR
```

Register slave accesses must reject misaligned, non-word, out-of-range, and
unknown register accesses.

## 6. Verification Requirements

Verification must cover register access, successful copies, deterministic random
copies, IRQ, zero length, misalignment, master read/write errors, and register
access errors.
