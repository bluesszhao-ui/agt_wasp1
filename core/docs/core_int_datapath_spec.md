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
core_hazard
core_wb
core_debug_ctrl
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
load-use hazard stall and execute bubble
Debug Mode halt-pending drain, halted status, resume, single-step re-halt, and execute trigger halt
halted-core GPR read/write access through `debug_if.core`
halted Debug PC capture through `debug_if.core.dpc`
DCSR cause reporting through `debug_if.core.dcsr_cause`
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

The frontend side uses the same lightweight instruction stream and redirect
interface as `core_pipe`:

```text
instr_valid_i
instr_ready_o
instr_pc_i
instr_i
instr_fault_i
redirect_valid_o
redirect_pc_o
```

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
hazard_load_use_o
hazard_fwd_rs1_ex_o
hazard_fwd_rs1_wb_o
hazard_fwd_rs2_ex_o
hazard_fwd_rs2_wb_o
timer_irq_i
external_irq_i
dmem_req_valid_o
dmem_req_ready_i
dmem_req_addr_o
dmem_req_write_o
dmem_req_size_o
dmem_req_wdata_o
dmem_req_wstrb_o
dmem_rsp_valid_i
dmem_rsp_ready_o
dmem_rsp_rdata_i
dmem_rsp_err_i
core_debug
```

## 5. Verification Requirements

Verification must cover immediate ALU, register ALU, write-after-read
dependencies through the register file timing, LUI, AUIPC, taken and not-taken
branches, JAL/JALR link writeback, redirect flush, load data extension, store
request formatting, data request/response wait-state behavior, LSU fault/trap
behavior, CSR read/write old-value writeback, ECALL trap entry, MRET redirect,
interrupt redirect, x0 suppression, illegal trap behavior, load-use
stall/bubble behavior, frontend PC stepping in the testbench model, Debug PC
capture on halt entry, and redirect target forwarding.

Debug verification must cover halt entry after the pipeline drains, frontend
ready suppression while halted, halted GPR read/write/readback, x0 debug access,
DPC resume-PC capture, DCSR cause reporting for halt/step/trigger, execute
trigger entry before the matched instruction retires, and resume back to
running state.
