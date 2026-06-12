# core_hazard Verification Plan

## 1. Strategy

`tb_core_hazard` is a self-checking SystemVerilog testbench with a local
reference model for dependency matching, forwarding priority, and load-use
stall detection.

## 2. Planned Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Idle | No matching destinations | No forwarding or stall |
| EX forward | rs1 and rs2 match execute rd | EX forwarding selected |
| WB forward | rs1 and rs2 match writeback rd | WB forwarding selected |
| Load-use | rs1 and rs2 match execute load rd | Stall and bubble asserted |
| x0 | Sources and destinations are x0 | No forwarding or stall |
| Priority | EX and WB match same source | EX forwarding wins |
| Invalid gating | Decode slot invalid | No forwarding or stall |
| Random | Deterministic random dependency checks | RTL matches reference model |

## 3. Coverage Goals

The bench must cover at least 2 EX forwarding cases, 2 WB forwarding cases, 2
load-use stall cases, 1 x0 suppression case, 1 priority case, and 200 random
cases.
