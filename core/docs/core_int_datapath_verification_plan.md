# core_int_datapath Verification Plan

## 1. Strategy

Use a self-checking SystemVerilog program-style testbench. The testbench drives
one instruction response per cycle, observes commit outputs after each pipeline
advance, and checks expected register writeback.

## 2. Directed Cases

| Case | Intent |
| --- | --- |
| Reset | Fetch PC equals boot PC and no commit occurs |
| ADDI | Immediate ALU writeback |
| ADDI dependency | Adjacent write/read dependency through regfile timing |
| ADD | Register-register ALU writeback |
| SUB | Register-register subtract writeback |
| ORI | Immediate logical writeback |
| LUI | U-immediate writeback |
| AUIPC | PC-relative writeback |
| BEQ taken | Conditional branch target redirect and younger instruction flush |
| BEQ not taken | Sequential PC flow without redirect |
| JAL link/redirect | PC+4 link writeback plus J-immediate redirect |
| JALR link/redirect | PC+4 link writeback plus aligned register-relative redirect |
| LW | Word load request and writeback |
| LB/LBU | Byte lane select plus sign/zero extension |
| SW/SB | Store request address, size, lane data, and byte strobes |
| Misaligned load | Request suppression and `lsu_fault_o` assertion |
| Memory response error | Request visibility, writeback suppression, and `lsu_fault_o` assertion |
| CSRRW | CSR old-value writeback and CSR state update |
| CSRRS read | CSR readback without changing state when rs1 is x0 |
| ECALL trap | Trap metadata, CSR trap entry, and redirect to `mtvec` |
| MRET | Redirect to `mepc` and mstatus restore path |
| Timer IRQ | CSR-enabled timer interrupt trap and redirect |
| x0 write | x0 writeback suppression |
| Illegal | Illegal instruction trap and writeback suppression |

## 3. Exit Criteria

All expected commits and suppressions must match. Coverage counters must show
ALU-immediate, ALU-register, upper-immediate, branch, link, redirect,
load, store, LSU fault, CSR, trap, interrupt, suppression, and PC stepping
coverage.
