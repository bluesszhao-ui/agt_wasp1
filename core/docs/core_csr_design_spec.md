# core_csr Design Spec

## 1. Scope

`core_csr` is a sequential machine-mode CSR file.

## 2. Block Diagram

```text
 csr_addr_i/cmd/wdata
          |
          v
 +------------------+      timer_irq_i
 | CSR read/write   |<-----external_irq_i
 | decode and masks |
 +---+----------+---+
     |          |
     v          v
 CSR regs    mip read image
     |
     +----> csr_rdata_o / csr_illegal_o
     |
 trap_valid_i/mret_i
     |
     v
 mstatus/mepc/mcause/mtval update
     |
     +----> mtvec_o, mepc_o, interrupt enable/pending outputs
```

## 3. Design

The CSR read path is combinational and returns the current CSR value.

The CSR write path computes the Zicsr write value as:

```text
RW  = csr_wdata_i
RS  = old | csr_wdata_i
RC  = old & ~csr_wdata_i
```

Immediate CSR instructions use the same operation after decode has already
zero-extended the immediate into `csr_wdata_i`.

Writable CSRs are committed on the rising edge. Trap updates take priority
over MRET and occur after normal CSR writes in the same sequential block.

## 4. Masks

`mstatus` stores only MIE, MPIE, and machine-mode MPP.

`mie` stores MTIE and MEIE.

`mtvec` is forced to direct mode by clearing bits `[1:0]`.

`mepc` clears bit zero on CSR write and trap entry.

## 5. Target Support

The module uses portable sequential and combinational RTL and does not require
target-specific IC or FPGA primitives.
