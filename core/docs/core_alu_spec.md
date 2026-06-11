# core_alu Spec

## 1. Purpose

`core_alu` performs RV32I integer arithmetic, logic, compare, and shift
operations for the core execution path.

## 2. Interface Requirements

Inputs:

```text
op_i
lhs_i
rhs_i
```

Output:

```text
result_o
```

All operands and results are 32-bit.

## 3. Operation Requirements

The ALU must support:

```text
ADD
SUB
SLL
SLT
SLTU
XOR
SRL
SRA
OR
AND
```

Shift amount must use `rhs_i[4:0]`.

Signed compare and arithmetic right shift must treat operands as signed
two's-complement 32-bit values.

## 4. Error and Default Requirements

Unsupported operation encodings must return zero.

## 5. Verification Requirements

Verification must cover every operation, edge operands, signed/unsigned
compare differences, shift amount masking, arithmetic shift sign extension, and
deterministic random checks against a reference model.
