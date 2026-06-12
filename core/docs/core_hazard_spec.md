# core_hazard Spec

## 1. Purpose

`core_hazard` detects simple in-order pipeline data hazards and selects
operand forwarding for the wasp1 core.

## 2. Functional Requirements

The module must detect dependencies from the decode-stage source registers to
the execute-stage and writeback-stage destination registers.

`x0` must never be treated as a true dependency.

Execute-stage forwarding must be selected for ALU-like results that are
available before writeback.

Writeback-stage forwarding must be selected when no execute-stage forwarding
for the same source is selected.

## 3. Load-Use Requirements

If the execute-stage instruction is a load and the decode-stage instruction
uses the same nonzero destination register, the module must assert:

```text
load_use_stall_o
fetch_stall_o
decode_stall_o
execute_bubble_o
```

Loads must not forward from execute.

## 4. Interface Requirements

Inputs describe decode, execute, and writeback pipeline slots:

```text
id_*: decode source register use
ex_*: execute destination and load status
wb_*: writeback destination
```

Outputs describe source forwarding and stall/bubble controls.

## 5. Verification Requirements

Verification must cover EX forwarding, WB forwarding, EX-over-WB priority,
load-use stalls on rs1 and rs2, x0 suppression, invalid slot gating, and
deterministic random dependency checks.
