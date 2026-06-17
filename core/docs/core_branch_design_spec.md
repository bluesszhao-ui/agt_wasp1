# core_branch Design Spec

## 1. Scope

`core_branch` is a combinational branch and jump helper used by the core
execute stage.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic
All logic blocks in this diagram are COMB. No DUT clock/reset is used.

 rs1_i --------+---------------------+
 rs2_i -------->| COMB branch cmp    |
 branch_op_i -->| eq/ne/signed/uns   |
                +----------+---------+
                           |
 pc_i ----+                v
 imm_i ---+-------> +-------------+
                  ->| COMB target |----> target_o
 jal_i -----------> | JAL/JALR/BR |
 jalr_i ----------> +------+------+
 branch_i ---------------> |
                           v
                        taken_o

 pc_i -------------------------> link_o = pc_i + 4
```

## 3. Design

The module has no sequential state.

Branch comparison is a `unique case` over `branch_op_i`. Signed branches cast
operands with `$signed`; unsigned branches use normal logic comparison.

Target generation computes:

```text
pc_plus_imm  = pc_i + imm_i
rs1_plus_imm = rs1_i + imm_i
link_o       = pc_i + 4
```

JALR target generation clears bit zero after addition.

## 4. Target Support

The module is target-neutral combinational logic. No IC or FPGA-specific
primitive is required.
