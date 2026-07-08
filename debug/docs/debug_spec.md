# debug Spec

## 1. Purpose

`debug` is the stage-1 single-hart Debug Module integration boundary. It targets
RISC-V External Debug Specification 0.13.x behavior sufficient for hart
discovery, halt/resume control, and RV32 integer GPR abstract access.
It also exposes physical Access Memory through the halted core plus the
`misa`, `mstatus`, `dcsr`, and core-captured `dpc` abstract CSR probes required
for OpenOCD/GDB discovery, register-packet reads, memory disassembly around PC,
native `stepi` setup, and one execute-address hardware breakpoint trigger.

The JTAG TAP/DTM transport is integrated with this Debug Module by the
`debug_jtag` wrapper. This module intentionally remains the ready/valid DMI
Debug Module register/control boundary.

## 2. External Contract

| Interface or signal | Direction | Required behavior |
| --- | --- | --- |
| `clk_i`, `rst_ni` | input | Shared Debug Module clock and active-low reset |
| `debug_dmi_if.dm dmi` | target | DMI request/response register access channel |
| `debug_if.dm core_debug` | initiator/control | Core halt/resume plus halted-core GPR and memory access channel |
| `hart_reset_event_i` | input | One-cycle hart reset observation for sticky `dmstatus.havereset` |
| `dmactive_o` | output | Mirrors active Debug Module state |
| `ndmreset_o` | output | Non-debug reset request from `dmcontrol.ndmreset` |

`core_debug.step_req` asserts during a resume transaction when the latched
`dcsr.step` bit is set. `core_debug.trigger_execute_valid` and
`core_debug.trigger_execute_addr` reflect the single supported `mcontrol`
trigger programmed through abstract trigger CSRs.

## 3. Implemented Functions

| Function | Requirement |
| --- | --- |
| DMI registers | Implement `data0`, `data1`, `dmcontrol`, `dmstatus`, `hartinfo`, `abstractcs`, and `command` |
| Hart control | Convert `haltreq/resumereq` register fields into core Debug Mode requests |
| Hart status | Report halted, running, resumeack, havereset, and nonexistent hart status |
| Abstract commands | Support RV32 integer Access Register commands for x0-x31, OpenOCD CSR probes, and physical Access Memory byte/half/word commands |
| GPR transport | Sequence one core GPR request and one response per abstract transfer |
| Memory transport | Sequence one halted-core memory request and one response per Access Memory command |
| Single-step | Convert `dcsr.step=1` plus `dmcontrol.resumereq` into `core_debug.step_req` |
| Hardware breakpoint | Provide one RV32 `mcontrol` execute-address trigger for OpenOCD/GDB `hbreak` |
| Error reporting | Preserve leaf-module `cmderr` mapping and DMI `FAILED` response behavior |

## 4. Unsupported Stage-1 Scope

The following are intentionally outside this module:

```text
program buffer
debug ROM
architectural CSR side effects beyond `dcsr.step`
multiple hardware triggers or data/load/store trigger modes
multi-hart selection beyond architectural nonexistent-hart reporting
```

## 5. Target Support

The module is synthesizable SystemVerilog and target-neutral. The target macros
`WASP1_TARGET_SIM_GENERIC`, `WASP1_TARGET_IC`, and
`WASP1_TARGET_FPGA_XILINX_VIRTEX7` must not change DMI-visible behavior.
