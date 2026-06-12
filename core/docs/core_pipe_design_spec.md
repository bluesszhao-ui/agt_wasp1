# core_pipe Design Spec

## 1. Scope

`core_pipe` is the initial pipeline-control integration skeleton for the
planned simple in-order core. This milestone intentionally does not execute
instruction semantics; it establishes the pipeline state machinery that later
connects decode, regfile, ALU, LSU, CSR, trap, hazard, and writeback logic.

## 2. Block Diagram

```text
                     redirect_valid/pc
                            |
                            v
 boot_pc ---> fetch PC register ---> frontend request PC
                            |
             frontend response valid/ready
                            |
                            v
                    +---------------+
                    | IF/ID slot    |
                    | pc/instr/flt  |
                    +-------+-------+
                            |
                 decode_stall / bubble controls
                            |
                            v
                    +---------------+
                    | EX/WB slot    |
                    | pc/instr/flt  |
                    +---------------+
```

## 3. Design

The fetch PC is initialized from `boot_pc_i`. A normal accepted frontend
response increments the fetch PC by four. A redirect overwrites the fetch PC
with `redirect_pc_i`.

The frontend response is accepted when:

```text
!fetch_stall_i && !decode_stall_i && !redirect_valid_i
```

Redirect has highest priority and clears both pipeline slots.

If `execute_bubble_i` is asserted, the EX/WB slot is cleared. Otherwise, when
decode is not stalled, IF/ID advances into EX/WB.

IF/ID captures a fetch response in the same cycle it advances. If no response
is accepted and decode is not stalled, IF/ID is cleared.

## 4. Target Support

The module is target-neutral synthesizable sequential logic. No IC or
Virtex-7-specific primitive is required.
