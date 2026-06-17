# core_trap Design Spec

## 1. Scope

`core_trap` is a combinational trap and redirect priority helper.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic
All logic blocks in this diagram are COMB. No DUT clock/reset is used.

 exception inputs ----+
 ecall/ebreak --------+--> COMB sync priority -----+
 lsu faults ----------+                             |
                                                   v
 irq pending/enables ---> COMB irq qualify ---> COMB redirect/trap mux ---> trap outputs
                                                   |
 mret_i / mepc_i ----------------------------------+
 mtvec_i ------------------------------------------+
```

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
