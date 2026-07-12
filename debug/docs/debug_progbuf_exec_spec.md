# debug_progbuf_exec Spec

## 1. Purpose

`debug_progbuf_exec` sequences the four stored Program Buffer words toward a
future halted-core instruction execution port. It is a protocol controller;
the storage array, DMI register routing, and core datapath are separate blocks.

## 2. External Contract

| Interface | Required behavior |
| --- | --- |
| `start_i` | Starts at word zero only while `dmactive_i && hart_halted_i` |
| `words_i` | Four stable RV32 instruction words for the active operation |
| `instr_*` request | Holds instruction and index stable until `instr_ready_i` |
| `instr_rsp_*` | Accepts exactly one completion for each accepted instruction |
| `busy_o` | High from accepted start through the one-cycle completion state |
| `done_o/error_o` | One-cycle completion with an abstract-command error code |

## 3. Execution Requirements

Only one instruction may be outstanding. A non-EBREAK word is issued, then the
controller waits for its response before advancing. `32'h0010_0073` is an
explicit EBREAK terminator and completes successfully without entering the
ordinary core trap path.

Because `impebreak=0`, all successful sequences must contain an explicit EBREAK.
Reaching the end of word three after executing a non-EBREAK instruction returns
`CMDERR_EXCEPTION`.

## 4. Error And Abort Behavior

| Condition | Result |
| --- | --- |
| Start or continue while hart is not halted | Complete with `CMDERR_HALT_RESUME` |
| Core reports instruction error | Complete with `CMDERR_EXCEPTION` |
| No EBREAK in four words | Complete with `CMDERR_EXCEPTION` |
| `dmactive_i` clears | Silently abort to idle and scrub index/error state |
| Reset asserts | Asynchronously return to idle with no completion pulse |

## 5. Target Support

The controller is target-neutral synthesizable SystemVerilog. Generic, IC, and
Xilinx Virtex-7 builds must have identical protocol and error behavior.
