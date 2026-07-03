# debug Spec

## 1. Purpose

`debug` is the stage-1 single-hart Debug Module integration boundary. It targets
RISC-V External Debug Specification 0.13.x behavior sufficient for hart
discovery, halt/resume control, and RV32 integer GPR abstract access.

The JTAG TAP/DTM transport is integrated with this Debug Module by the
`debug_jtag` wrapper. This module intentionally remains the ready/valid DMI
Debug Module register/control boundary.

## 2. External Contract

| Interface or signal | Direction | Required behavior |
| --- | --- | --- |
| `clk_i`, `rst_ni` | input | Shared Debug Module clock and active-low reset |
| `debug_dmi_if.dm dmi` | target | DMI request/response register access channel |
| `debug_if.dm core_debug` | initiator/control | Core halt/resume and halted-core GPR access channel |
| `hart_reset_event_i` | input | One-cycle hart reset observation for sticky `dmstatus.havereset` |
| `dmactive_o` | output | Mirrors active Debug Module state |
| `ndmreset_o` | output | Non-debug reset request from `dmcontrol.ndmreset` |

`core_debug.step_req` is hardwired low in stage 1. Single-step is reserved for a
later Debug Module milestone.

## 3. Implemented Functions

| Function | Requirement |
| --- | --- |
| DMI registers | Implement `data0`, `dmcontrol`, `dmstatus`, `hartinfo`, `abstractcs`, and `command` |
| Hart control | Convert `haltreq/resumereq` register fields into core Debug Mode requests |
| Hart status | Report halted, running, resumeack, havereset, and nonexistent hart status |
| Abstract commands | Support RV32 integer Access Register commands for x0-x31 |
| GPR transport | Sequence one core GPR request and one response per abstract transfer |
| Error reporting | Preserve leaf-module `cmderr` mapping and DMI `FAILED` response behavior |

## 4. Unsupported Stage-1 Scope

The following are intentionally outside this module:

```text
SoC-level JTAG pin integration through `debug_jtag`
OpenOCD/GDB end-to-end transport
single-step
program buffer
abstract memory access
debug ROM
multi-hart selection beyond architectural nonexistent-hart reporting
```

## 5. Target Support

The module is synthesizable SystemVerilog and target-neutral. The target macros
`WASP1_TARGET_SIM_GENERIC`, `WASP1_TARGET_IC`, and
`WASP1_TARGET_FPGA_XILINX_VIRTEX7` must not change DMI-visible behavior.
