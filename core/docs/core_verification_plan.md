# core Verification Plan

## 1. Verification Scope

This plan verifies the first `core` top-level wrapper around
`core_int_datapath`. Since the wrapper owns no independent datapath or FSM logic,
standalone `core` verification focuses on public interface mapping and a compact
integrated instruction sequence.

Full instruction, CSR, trap, load/store, branch, hazard, and suppression coverage
is provided by the underlying submodule and `core_int_datapath` plans.

## 2. Testbench

```text
testbench: core/tb/tb_core.sv
filelist:  core/filelists/tb_core.f
target:    make -C core sim-core
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Coverage Goals

| Goal | Method |
| --- | --- |
| Reset boundary | Check `boot_pc_i` appears on `if_req_pc_o` after reset. |
| Instruction interface | Drive valid/ready instruction responses and check PC sequencing. |
| Commit observation | Execute ALU and load instructions and check writeback outputs. |
| Data interface | Execute `lw` and check request address, size, and readback commit. |
| Hazard observation | Execute load-use dependency and check public stall output. |
| Trap observation | Execute illegal instruction and check trap redirect outputs. |
| Suppression behavior | Check NOP/no-write slot does not assert commit. |

## 4. Time-Sequenced Case Plan

| Time window | Action | Expected result |
| --- | --- | --- |
| 0ns-20ns | Hold reset active. | Fetch PC equals boot PC, no execute, no commit, no trap. |
| 20ns-50ns | Release reset and feed two ADDI instructions. | First ADDI commits `x1=5`; fetch PC increments by 4. |
| 50ns-70ns | Feed ADD instruction. | Second ADDI commits `x2=8`; forwarding path is observable by result sequence. |
| 70ns-90ns | Feed base ADDI for data load. | ADD commits `x3=13`; base register is prepared. |
| 90ns-110ns | Feed `lw x21,0(x20)`. | Data request address is `0x300`, size is word, load commits `0xCAFE_BABE`. |
| 110ns-130ns | Feed dependent `add x22,x21,x0`. | Load-use hazard stalls fetch/decode and injects one execute bubble. |
| 130ns-150ns | Feed NOP drain. | Dependent add commits loaded value. |
| 150ns-180ns | Feed illegal instruction and flushed fall-through. | Illegal trap is reported and fetch redirects to `mtvec=0`. |

## 5. Pass Criteria

Simulation must finish with `tb_core PASS`, all self-checks passing, and the
coverage summary meeting minimum counters for commit, fetch, data-memory,
hazard, trap, and suppression observations.
