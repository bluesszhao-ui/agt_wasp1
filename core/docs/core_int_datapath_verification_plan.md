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
| JAL link | PC+4 link writeback |
| x0 write | x0 writeback suppression |
| Illegal | Illegal instruction suppresses writeback |
| Load unsupported | Unsupported class suppresses writeback |

## 3. Exit Criteria

All expected commits and suppressions must match. Coverage counters must show
ALU-immediate, ALU-register, upper-immediate, link, suppression, and PC stepping
coverage.
