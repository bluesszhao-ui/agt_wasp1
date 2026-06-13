# core_int_datapath Spec

## 1. Purpose

`core_int_datapath` is the first executable integer datapath integration for
the wasp1 core.

It connects:

```text
core_pipe
core_decode
core_regfile
core_alu
core_branch
core_wb
```

## 2. Supported Instruction Scope

This milestone supports register writeback for:

```text
RV32I OP-IMM ALU instructions
RV32I OP register-register ALU instructions
LUI
AUIPC
conditional branch redirect
JAL/JALR link writeback and redirect
```

## 3. Unsupported Instruction Scope

The following instruction classes are decoded but suppress architectural
writeback in this milestone:

```text
load/store
CSR/system/trap
illegal instruction
fetch fault
```

## 4. Interface Requirements

The frontend side uses the same lightweight fetch request/response interface as
`core_pipe`.

The module exposes commit observation outputs for staged verification:

```text
commit_valid_o
commit_rd_o
commit_data_o
ex_valid_o
ex_pc_o
ex_instr_o
illegal_o
unsupported_o
```

## 5. Verification Requirements

Verification must cover immediate ALU, register ALU, write-after-read
dependencies through the register file timing, LUI, AUIPC, taken and not-taken
branches, JAL/JALR link writeback, redirect flush, x0 suppression, illegal
suppression, unsupported suppression, and fetch PC stepping.
