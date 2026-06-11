# core_csr Spec

## 1. Purpose

`core_csr` implements the minimal machine-mode CSR file required by the wasp1
RV32I + Zicsr core.

## 2. Supported CSRs

The module must support:

```text
mstatus
mie
mtvec
mscratch
mepc
mcause
mtval
mip
cycle/cycleh
instret/instreth
```

CSR addresses come from `common/rtl/wasp1_pkg.sv`.

## 3. CSR Instruction Requirements

The module must implement the Zicsr operations:

```text
CSRRW / CSRRWI
CSRRS / CSRRSI
CSRRC / CSRRCI
```

`csr_rdata_o` must return the old CSR value while the write operation is
requested.

Read-only CSRs and unsupported CSR addresses must assert `csr_illegal_o` when
accessed through a CSR operation.

## 4. Machine Status Requirements

`mstatus` must implement:

```text
MIE
MPIE
MPP
```

Because wasp1 currently supports machine mode only, `MPP` is held at machine
mode.

## 5. Trap and Interrupt Requirements

On `trap_valid_i`, the module must:

```text
mepc   = trap_pc_i with bit 0 cleared
mcause = {trap_interrupt_i, trap_cause_i}
mtval  = trap_tval_i
MPIE   = previous MIE
MIE    = 0
MPP    = machine mode
```

On `mret_i`, the module must restore `MIE` from `MPIE` and set `MPIE`.

`mip` must reflect `timer_irq_i` and `external_irq_i`. `mie` must expose
machine timer and machine external interrupt enable bits.

## 6. Counter Requirements

`cycle/cycleh` must increment every active clock cycle after reset.

`instret/instreth` must increment when `retire_i` is asserted.

## 7. Verification Requirements

Verification must cover CSR read/write/set/clear semantics, masks, read-only
illegal accesses, unsupported address illegal accesses, trap/MRET behavior,
interrupt pending/enables, and counter increments.
