# core_pipe Verification Plan

## 1. Strategy

Use a self-checking SystemVerilog testbench with a cycle-by-cycle reference
model for frontend-side stream PC, IF/ID state, and EX/WB state.

## 2. Directed Cases

| Case | Intent |
| --- | --- |
| Reset | Pipeline slots are invalid |
| Fetch A | First instruction stream beat enters IF/ID |
| Fetch B | IF/ID advances to EX/WB while new stream beat enters IF/ID |
| Stall hold | Fetch/decode stall holds state and blocks stream acceptance |
| Bubble hold | Execute bubble clears EX/WB while IF/ID is held |
| Release advance | Held IF/ID advances after stall release |
| Fetch fault | Fault metadata enters IF/ID |
| Fault advance | Fault metadata advances to EX/WB |
| Redirect flush | Redirect clears both slots and forwards redirect PC |
| Frozen debug injection | Debug word enters empty IF/ID while normal stalls are asserted |
| Frontend exclusion | Debug valid suppresses normal `instr_ready_o` |
| Debug backpressure | Occupied ID/EX prevents a second debug acceptance |
| Tag advance/clear | Debug source tag advances to EX/WB and clears with the slot |
| Redirect priority | Simultaneous redirect flushes and rejects debug injection |

## 3. Random Cases

Run 120 deterministic random cycles over instruction valid, PC, instruction data,
fault flag, fetch stall, decode stall, execute bubble, redirect valid, and
redirect target.

## 4. Exit Criteria

All directed and random cycles must match the reference model. Coverage counters
must show fetch acceptance, decode advance, stall, bubble, redirect, fetch
fault, debug injection/backpressure/redirect priority, and random paths were
exercised.
