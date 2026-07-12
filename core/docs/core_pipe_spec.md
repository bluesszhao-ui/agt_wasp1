# core_pipe Spec

## 1. Purpose

`core_pipe` owns the first wasp1 core pipeline control skeleton: IF/ID pipeline
slot state, EX/WB pipeline slot state, instruction-stream acceptance, stall
handling, bubble insertion, and redirect flushing.
It also accepts one halted-core debug instruction into an otherwise empty
pipeline and carries an explicit source tag through EX/WB.

Fetch PC generation is owned by `frontend`. `core_pipe` consumes an instruction
stream that already carries its PC, and forwards branch/trap/MRET redirects back
to the frontend.

## 2. Functional Requirements

The module must accept instructions from the frontend only when fetch/decode are
not stalled and no redirect is being applied.

Accepted instruction stream beats must enter the IF/ID slot with their PC and
fetch-fault metadata.

When decode is allowed to advance, the IF/ID slot must move into the EX/WB
slot. If no new instruction stream beat is accepted in the same cycle, IF/ID
becomes invalid.

## 3. Stall, Bubble, and Redirect Requirements

`fetch_stall_i` must suppress instruction stream acceptance.

`decode_stall_i` must hold the IF/ID slot and suppress instruction stream
acceptance.

`execute_bubble_i` must clear the EX/WB slot while allowing IF/ID to remain
held when decode is stalled.

`redirect_valid_i` has highest priority. It must flush IF/ID and EX/WB and set
`redirect_valid_o`/`redirect_pc_o` toward the frontend.

## 4. Interface Requirements

The frontend-to-core instruction interface is a lightweight valid/ready stream:

```text
instr_valid_i / instr_ready_o / instr_pc_i / instr_i / instr_fault_i
redirect_valid_o / redirect_pc_o
```

Visible IF/ID and EX/WB outputs are provided for later decode/execute
integration and for staged verification.

The debug injection interface is:

```text
debug_inject_valid_i / debug_inject_ready_o
debug_inject_pc_i / debug_inject_instr_i
id_debug_o / ex_debug_o
```

Injection may be accepted only while both slots are empty and no redirect is
active. An asserted debug request suppresses `instr_ready_o`, preventing a
simultaneous frontend acceptance. Accepted debug words have fetch fault clear
and source tag set.

Update priority is reset, redirect, accepted debug injection, then normal
pipeline update. Injection bypasses fetch/decode stalls because those stalls
are intentionally asserted while the core is halted.

## 5. Verification Requirements

Verification must cover reset invalid state, normal instruction acceptance and
advance, stalls, execute bubbles, redirect flush/forwarding, fetch fault
propagation, and random control interleavings.
Verification must additionally cover frozen-pipeline injection, debug request
backpressure, frontend exclusion, tag advance/clear, and redirect priority.
