# core_pipe Spec

## 1. Purpose

`core_pipe` owns the first wasp1 core pipeline control skeleton: fetch PC state,
IF/ID pipeline slot state, EX/WB pipeline slot state, stall handling, bubble
insertion, and redirect flushing.

## 2. Functional Requirements

The module must request instructions from the frontend using the current fetch
PC and accept frontend responses only when fetch/decode are not stalled and no
redirect is being applied.

Accepted instruction responses must enter the IF/ID slot with their PC and
fetch-fault metadata.

When decode is allowed to advance, the IF/ID slot must move into the EX/WB
slot. If no new fetch response is accepted in the same cycle, IF/ID becomes
invalid.

## 3. Stall, Bubble, and Redirect Requirements

`fetch_stall_i` must suppress fetch request valid and response acceptance.

`decode_stall_i` must hold the IF/ID slot and suppress response acceptance.

`execute_bubble_i` must clear the EX/WB slot while allowing IF/ID to remain
held when decode is stalled.

`redirect_valid_i` has highest priority. It must flush IF/ID and EX/WB and set
the fetch PC to `redirect_pc_i`.

## 4. Interface Requirements

The frontend interface is a lightweight request/response pair:

```text
if_req_valid_o / if_req_pc_o
if_rsp_valid_i / if_rsp_ready_o / if_rsp_instr_i / if_rsp_fault_i
```

Visible IF/ID and EX/WB outputs are provided for later decode/execute
integration and for staged verification.

## 5. Verification Requirements

Verification must cover reset PC, normal fetch and advance, stalls, execute
bubbles, redirect flush, fetch fault propagation, and random control
interleavings.
