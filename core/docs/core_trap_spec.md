# core_trap Spec

## 1. Purpose

`core_trap` selects synchronous traps, MRET redirects, and enabled machine
interrupts for the wasp1 RV32I + Zicsr core.

## 2. Supported Events

The module must support:

```text
instruction address misaligned
illegal instruction
illegal CSR access
EBREAK
ECALL from machine mode
load address misaligned
store address misaligned
MRET
machine timer interrupt
machine external interrupt
```

## 3. Priority Requirements

For a valid instruction slot, priority must be:

```text
synchronous trap
MRET redirect
machine external interrupt
machine timer interrupt
no redirect
```

Synchronous trap priority must be:

```text
instruction address misaligned
illegal instruction / illegal CSR
EBREAK
ECALL
load address misaligned
store address misaligned
```

## 4. Redirect Requirements

Synchronous traps and interrupts redirect to `mtvec_i`.

MRET redirects to `mepc_i`.

When `valid_i` is deasserted, no trap or redirect may be generated.

## 5. CSR Trap Write Requirements

For traps, the module must output:

```text
trap_valid_o
trap_interrupt_o
trap_cause_o
trap_tval_o
trap_pc_o
```

These outputs are intended to drive `core_csr` trap inputs.

## 6. Verification Requirements

Verification must cover every supported synchronous trap, enabled and masked
interrupts, MRET redirect, valid gating, and priority between synchronous traps,
MRET, and interrupts.
