# core_alu Design Spec

## 1. Scope

`core_alu` is a combinational execution submodule.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic
All logic blocks in this diagram are COMB. No DUT clock/reset is used.

 lhs_i --------+
               |
 rhs_i ----+   v
          | +----------------+
 op_i ----->| COMB op mux    |
            | add/sub/logic  |
            | shift/compare  |
            +--------+-------+
                     |
                     v
                  result_o
```

## 3. Design

The module uses one `always_comb` block and a unique case over `op_i`.

Shift operations use only `rhs_i[4:0]`.

Signed operations cast operands with `$signed`.

## 4. Target Support

The ALU is target-neutral combinational logic. No IC or FPGA-specific primitive
is required.
