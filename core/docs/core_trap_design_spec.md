# core_trap Design Spec

## 1. Scope

`core_trap` is a combinational trap and redirect priority helper.

## 2. Editable Block Diagram

```text
editable source: core/docs/diagrams/core_trap_block.graffle
preview export:  none
detail level:    L1
clock domains:   none; pure combinational logic
```

The diagram separates synchronous trap inputs and priority logic, interrupt
qualification, the MRET redirect path, final trap/redirect muxing, and trap
outputs. No DUT clock, reset, register, counter, or FSM state exists in this
module.

## 3. Design

The module first checks synchronous trap sources for the current valid
instruction slot. If a synchronous trap is selected, it emits trap metadata and
redirects to `mtvec_i`.

If no synchronous trap exists and `mret_i` is asserted, the module redirects to
`mepc_i` without asserting `trap_valid_o`.

If no synchronous trap or MRET exists, enabled external interrupt is selected
before enabled timer interrupt. Interrupts assert `trap_interrupt_o` and
redirect to `mtvec_i`.

## 4. Target Support

The module is target-neutral combinational logic. No IC or FPGA-specific
primitive is required.
