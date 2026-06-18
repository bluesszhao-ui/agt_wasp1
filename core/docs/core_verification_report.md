# core Verification Report

## 1. Result

Status: PASS.

## 2. Testbench

```text
testbench: core/tb/tb_core.sv
filelist:  core/filelists/tb_core.f
target:    make -C core sim-core
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Hold reset active. | No execute, commit, or trap. | PASS: reset observation matched. |
| 20ns-46ns | Release reset and feed ADDI sequence. | `x1=5` commits and stream PC model increments. | PASS: first commit and stream stepping matched. |
| 46ns-56ns | Feed ADD instruction. | `x2=8` commits and ADD enters pipe. | PASS: second commit matched. |
| 56ns-66ns | Feed base ADDI. | `x3=13` commits and base register is prepared. | PASS: ADD commit matched. |
| 66ns-86ns | Feed word load. | Data request address `0x300`, word size, readback commit. | PASS: data request and load commit matched. |
| 86ns-106ns | Feed dependent ADD. | Load-use stall output asserts and one execute bubble is injected. | PASS: hazard and bubble matched. |
| 106ns-116ns | Feed NOP drain. | Dependent ADD commits loaded value. | PASS: dependent ADD committed `0xCAFE_BABE`. |
| 116ns-126ns | Feed illegal instruction and fall-through NOP. | Illegal trap asserts `redirect_pc_o=0x00000000`. | PASS: trap outputs and redirect matched. |

## 4. Coverage Summary

```text
tb_core coverage: pass_count=9 commit=6 fetch=9 dmem=1 hazard=1 trap=1 suppress=1
tb_core PASS
```

Integrated core regression also passed:

```text
tb_core_alu PASS
tb_core_regfile PASS
tb_core_decode PASS
tb_core_branch PASS
tb_core_csr PASS
tb_core_lsu PASS
tb_core_trap PASS
tb_core_hazard PASS
tb_core_wb PASS
tb_core_pipe PASS
tb_core_int_datapath PASS
tb_core PASS
```

## 5. Commands

Executed:

```text
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim-core
make -C core sim
```
