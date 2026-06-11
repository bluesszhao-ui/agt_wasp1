# ahb_dma Design Spec

## 1. Scope

`ahb_dma` is the first single-channel DMA block for wasp1.

It exposes an AHB-Lite slave register interface for software configuration and
an AHB-Lite master interface for memory-to-memory word copies.

## 2. Block Diagram

```text
              hclk_i / hresetn_i
                      |
                      v
 s_hsel_i --------+----------------+
 s_haddr_i ------>| register slave |
 s_htrans_i ----->| range/alignment|
 s_hwrite_i ----->| word-only check|
 s_hwdata_i ----->| SRC DST LEN    |
                 +--------+-------+
                          |
                          v
                 +----------------+
                 | DMA control FSM|
                 | idle/read/write|
                 +--------+-------+
                          |
         +----------------+----------------+
         |                                 |
         v                                 v
 +----------------+               +----------------+
 | AHB master     |-------------->| SoC AHB fabric |
 | read SRC words |<--------------| memories/slaves |
 | write DST words|               +----------------+
 +--------+-------+
          |
          v
 +----------------+
 | status / irq   |
 | busy done error|
 +--------+-------+
          |
      dma_irq_o
```

## 3. Register Map

Offsets are relative to `DMA_BASE`.

| Offset | Register | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `DMA_SRC` | R/W | Source byte address |
| `0x04` | `DMA_DST` | R/W | Destination byte address |
| `0x08` | `DMA_LEN` | R/W | Transfer length in 32-bit words |
| `0x0C` | `DMA_CTRL` | R/W | bit0 start, bit1 irq_enable, bit2 clear done/error |
| `0x10` | `DMA_STATUS` | R | bit0 busy, bit1 done, bit2 error |

## 4. Behavior

The first DMA implementation supports one single-channel copy mode:

```text
word-sized memory-to-memory copy
one AHB read followed by one AHB write per word
no burst
no unaligned transfer
no cache coherence management
```

Start is accepted when:

```text
DMA is idle
LEN is nonzero
SRC and DST are word aligned
```

On successful completion:

```text
STATUS.done = 1
STATUS.error = 0
```

On rejected start or AHB master error:

```text
STATUS.done = 0
STATUS.error = 1
```

`DMA_CTRL.clear` clears sticky `done` and `error`. `dma_irq_o` is asserted when
`irq_enable` is set and either `done` or `error` is sticky.

## 5. AHB-Lite Behavior

Slave register interface:

```text
cycle N:
  capture selected NONSEQ/SEQ address/control

cycle N+1:
  return registered read data or write response
```

Only aligned word register accesses are supported.

Master interface:

```text
read address phase
read response phase
write address phase
write response phase
repeat until LEN words complete
```

The master uses `HTRANS=NONSEQ`, `HSIZE=word`, and `HBURST=single`.

Error response:

```text
register out-of-range transfer -> ERROR
misaligned register transfer   -> ERROR
non-word register transfer     -> ERROR
unknown register access        -> ERROR
AHB master read/write HRESP    -> STATUS.error
```

## 6. Implementation Targets

`ahb_dma` is target-neutral synthesizable logic. It includes
`common/rtl/wasp1_target_defs.svh` and is linted for:

```text
generic simulation
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```

No target-specific memory macro or FPGA primitive is required.

## 7. Verification Summary

Verified by `tb_ahb_dma`.

Coverage includes:

```text
reset output state
register read/write paths
successful 4-word copy
4 deterministic random copy cases
done IRQ
zero-length start error
misaligned source error
master read error
master write error
misaligned, unsupported size, and unknown register errors
generic, IC, and Virtex-7 target lint
```
