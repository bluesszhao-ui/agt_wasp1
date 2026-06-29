# core_alu Design Spec

## 1. Scope

`core_alu` is a combinational execution submodule.

## 2. Editable Block Diagram

```text
editable source: core/docs/diagrams/core_alu_block.graffle
preview export:  none
detail level:    L1
clock domains:   none; pure combinational logic
```

The diagram separates operand/opcode inputs, the combinational ALU operation
mux, and the result interface. No DUT clock, reset, register, counter, or FSM
state exists in this module.

## 3. Design

The module uses one `always_comb` block and a unique case over `op_i`.

Shift operations use only `rhs_i[4:0]`.

Signed operations cast operands with `$signed`.

## 4. Target Support

The ALU is target-neutral combinational logic. No IC or FPGA-specific primitive
is required.
