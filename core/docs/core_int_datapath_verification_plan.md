# core_int_datapath Verification Plan

## 1. Strategy

Use a self-checking SystemVerilog program-style testbench. The testbench drives
one frontend instruction stream beat per cycle, observes commit outputs after
each pipeline advance, and checks expected register writeback.

## 2. Directed Cases

| Case | Intent |
| --- | --- |
| Reset | No commit or trap occurs while reset is active |
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
| Data response wait | Delay data response after request fire and check pipeline holds until `dmem_rsp_valid_i && dmem_rsp_ready_o` |
| Data request backpressure | Deassert `dmem_req_ready_i` and check request remains valid while pipeline holds |
| CSRRW | CSR old-value writeback and CSR state update |
| CSRRS read | CSR readback without changing state when rs1 is x0 |
| ECALL trap | Trap metadata, CSR trap entry, and redirect to `mtvec` |
| MRET | Redirect to `mepc` and mstatus restore path |
| Timer IRQ | CSR-enabled timer interrupt trap and redirect |
| Load-use hazard | Dependent ID instruction stalls stream/decode and injects EX bubble |
| x0 write | x0 writeback suppression |
| Illegal | Illegal instruction trap and writeback suppression |
| Debug halt | Assert halt, drain pipeline, and check halted status plus frontend backpressure |
| Debug GPR read/write | Read a committed register, write/read back another register, and prove x0 remains zero |
| Debug resume | Resume from halted state and check running status returns |

## 3. Exit Criteria

All expected commits and suppressions must match. Coverage counters must show
ALU-immediate, ALU-register, upper-immediate, branch, link, redirect,
load, store, LSU fault, data-memory wait state, request backpressure, CSR,
trap, interrupt, load-use hazard, suppression, frontend-model PC stepping, and
debug halt/GPR/resume coverage.
