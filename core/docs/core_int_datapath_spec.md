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
core_lsu
core_csr
core_trap
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
LB/LBU/LH/LHU/LW load writeback
SB/SH/SW store request formatting
Zicsr read/write/set/clear register and immediate operations
ECALL/EBREAK/illegal/CSR-fault trap redirect
MRET redirect
machine timer/external interrupt trap inputs
```

## 3. Unsupported Instruction Scope

The following cases still suppress architectural register writeback in this
milestone:

```text
illegal instruction
fetch fault
load/store response error
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
lsu_fault_o
trap_valid_o
trap_interrupt_o
trap_cause_o
trap_tval_o
trap_pc_o
mret_taken_o
csr_rdata_o
timer_irq_i
external_irq_i
dmem_req_valid_o
dmem_req_addr_o
dmem_req_write_o
dmem_req_size_o
dmem_req_wdata_o
dmem_req_wstrb_o
dmem_rsp_rdata_i
dmem_rsp_err_i
```

## 5. Verification Requirements

Verification must cover immediate ALU, register ALU, write-after-read
dependencies through the register file timing, LUI, AUIPC, taken and not-taken
branches, JAL/JALR link writeback, redirect flush, load data extension, store
request formatting, LSU fault/trap behavior, CSR read/write old-value
writeback, ECALL trap entry, MRET redirect, interrupt redirect, x0 suppression,
illegal trap behavior, and fetch PC stepping.
