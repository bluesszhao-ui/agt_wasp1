# debug_progbuf_exec Verification Plan

## 1. Scope

Verify sequencing and error policy with a self-checking mock core endpoint.

## 2. Cases

| Case | Stimulus | Expected result |
| --- | --- | --- |
| Immediate EBREAK | Word zero is EBREAK | Success with no core request |
| Ordered execution | Three instructions followed by EBREAK | Indices 0, 1, 2 issue once and complete successfully |
| Request backpressure | Hold `instr_ready_i=0` | Request fields remain stable and index does not advance |
| Response latency | Delay `instr_rsp_valid_i` | Controller remains busy with response ready asserted |
| Core exception | Return `instr_rsp_error_i=1` | Stop immediately with `CMDERR_EXCEPTION` |
| Missing EBREAK | Four ordinary instructions | Execute all four, then report `CMDERR_EXCEPTION` |
| Halt loss | Drop `hart_halted_i` in ISSUE and WAIT | Stop with `CMDERR_HALT_RESUME` |
| DM abort | Clear `dmactive_i` in ISSUE and WAIT | Return idle silently with state scrubbed |
| Inactive start | Pulse `start_i` while `dmactive_i=0` | Remain idle with no request or completion |
| Busy start | Pulse `start_i` during an operation | Existing sequence is unaffected |
| Reset abort | Assert reset in WAIT | Return idle without stale request/completion |
| Random latency | Seeded request/response delays across legal sequences | Scoreboard observes ordered, exactly-once issue |

## 3. Coverage Goals

Cover every physical index, every FSM state, request and response backpressure,
both completion errors, immediate and late EBREAK, two hart-loss points, two DM
abort points, reset abort, ignored busy start, and at least 64 random sequences.
