# frontend_fetch Spec

## 1. Purpose

`frontend_fetch` translates accepted frontend PC requests into instruction-memory
read requests and returns fetched instruction responses to the frontend
consumer.

## 2. Functional Requirements

`frontend_fetch` must:

```text
accept one PC request at a time
issue read-only word instruction requests for aligned PCs
set req_instr on instruction-memory requests
hold an outstanding request until a response is consumed or dropped
propagate memory response data and error as instruction response data/fault
generate an immediate fault response for misaligned PCs without memory request
preserve the PC associated with each memory response
drop outstanding responses after flush_i is asserted
block new PC acceptance while waiting for an outstanding response
respect instruction response backpressure
```

## 3. Interface Contract

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | Frontend clock. |
| `rst_ni` | input | Active-low asynchronous reset. |
| `pc_valid_i` | input | PC request valid from `frontend_pc`. |
| `pc_ready_o` | output | Fetch can accept the current PC. |
| `pc_i` | input | PC request address. |
| `pc_misaligned_i` | input | Current PC is not word aligned. |
| `flush_i` | input | Drop current/new fetch due to redirect. |
| `instr_valid_o` | output | Instruction response valid. |
| `instr_ready_i` | input | Instruction response accepted. |
| `instr_pc_o` | output | PC for the response. |
| `instr_o` | output | Instruction word; zero for local misaligned fault. |
| `instr_fault_o` | output | Fetch fault from memory or local misalignment. |
| `instr_misaligned_o` | output | Fault is due to a misaligned PC. |
| `imem_if` | initiator | Read-only instruction memory/cache request interface. |

## 4. Flush Requirements

When `flush_i` is asserted while a memory request is outstanding, the eventual
memory response must be consumed and not delivered as `instr_valid_o`.

When `flush_i` is asserted while idle, no new PC request may be accepted.

## 5. Target Requirements

`frontend_fetch` is target-neutral and must not change behavior across IC,
Virtex-7 FPGA, or generic simulation targets.
