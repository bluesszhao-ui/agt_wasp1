# core_branch Spec

## 1. Purpose

`core_branch` decides RV32I branch and jump control flow in the core execute
path.

## 2. Functional Requirements

The module must support:

```text
BEQ
BNE
BLT
BGE
BLTU
BGEU
JAL
JALR
```

`JAL` and taken branches must target `pc_i + imm_i`.

`JALR` must target `(rs1_i + imm_i) & ~1`.

`link_o` must always report `pc_i + 4`.

When no branch or jump is taken, `taken_o` must be zero and `target_o` must be
`pc_i + 4`.

## 3. Interface Requirements

Inputs:

```text
pc_i
rs1_i
rs2_i
imm_i
branch_i
branch_op_i
jal_i
jalr_i
```

Outputs:

```text
taken_o
target_o
link_o
```

## 4. Priority Requirements

If multiple control-flow class inputs are asserted at once, the priority must
be:

```text
JAL
JALR
taken branch
fall-through
```

## 5. Verification Requirements

Verification must cover every branch condition in taken and not-taken forms,
signed and unsigned compare edge cases, forward/backward JAL, JALR bit-zero
clearing, priority behavior, and deterministic random branch comparisons.
