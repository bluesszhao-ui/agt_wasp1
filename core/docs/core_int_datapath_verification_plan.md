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
| Debug trigger | Enable execute-address trigger at next PC, prove matched instruction halts before retirement with DPC/cause set, clear trigger, and resume |
| Debug load trigger | Match an EX-stage load effective address, prove no request/retire/fault side effect, check DPC/cause, clear trigger, resume, and execute the load once |
| Debug store trigger | Match an EX-stage store effective address, prove no write request/retire side effect, check DPC/cause, clear trigger, resume, and execute the store once |
| Debug trigger isolation | Prove load-only does not match store and store-only does not match load; unmatched addresses execute normally |
| Debug resume | Resume from halted state and check running status returns |
| Debug injected ADDI | Execute one tagged ADDI while halted and verify GPR writeback without frontend release |
| Debug injected load/store | Reuse the normal LSU path and check request address/direction plus load writeback |
| Debug execution response backpressure | Hold response ready low and prove valid/error/DPC remain stable and a second request is blocked |
| Debug execution errors | Inject illegal, misaligned LW, and JAL words; require error response with no writeback, trap, redirect, request (for misalignment), or architectural fault output |
| Debug trap-CSR isolation | Read `mcause` through an injected CSRRS after error cases and prove prior timer-IRQ state was preserved |

## 3. Exit Criteria

All expected commits and suppressions must match. Coverage counters must show
ALU-immediate, ALU-register, upper-immediate, branch, link, redirect,
load, store, LSU fault, data-memory wait state, request backpressure, CSR,
trap, interrupt, load-use hazard, suppression, frontend-model PC stepping, and
debug halt/GPR/injected-execution/backpressure/error/execute-trigger/load-trigger/
store-trigger/isolation/resume coverage.
