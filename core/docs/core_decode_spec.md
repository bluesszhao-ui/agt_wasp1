# core_decode Spec

## 1. Purpose

`core_decode` decodes one 32-bit RV32I/Zicsr instruction into control fields
used by the wasp1 core pipeline.

## 2. ISA Scope

The decoder must recognize:

```text
RV32I integer register-register instructions
RV32I integer register-immediate instructions
RV32I loads and stores
RV32I branches and jumps
LUI and AUIPC
Zicsr CSR instructions
ECALL, EBREAK, and MRET
```

The decoder must reject unsupported or reserved encodings, including RV32M
`funct7=0000001` register-register encodings.

## 3. Interface Requirements

Input:

```text
instr_i
```

Decoded outputs:

```text
rd_o
rs1_o
rs2_o
imm_o
imm_sel_o
uses_rs1_o
uses_rs2_o
writes_rd_o
alu_valid_o
alu_op_o
alu_src_imm_o
load_o
store_o
lsu_size_o
lsu_unsigned_o
branch_o
branch_op_o
jal_o
jalr_o
lui_o
auipc_o
csr_o
csr_cmd_o
csr_addr_o
ecall_o
ebreak_o
mret_o
illegal_o
```

## 4. Immediate Requirements

The decoder must produce sign-extended I/S/B/J immediates and zero-low-bit
U-type immediates. CSR immediate instructions must expose the `zimm` field in
`imm_o[4:0]`.

## 5. Illegal Instruction Requirements

`illegal_o` must assert for unknown opcodes, invalid load/store/branch
`funct3` values, invalid shift immediate `funct7` values, invalid JALR
`funct3`, invalid SYSTEM encodings, and excluded RV32M encodings.

## 6. Verification Requirements

Verification must cover all supported instruction classes, every RV32I ALU
operation, every supported branch/load/store kind, CSR command decoding,
system instructions, immediate extraction, and representative illegal
encodings.
