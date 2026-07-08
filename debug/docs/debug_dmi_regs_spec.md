# debug_dmi_regs Spec

## 1. Purpose

`debug_dmi_regs` implements the first-stage RISC-V Debug Module register set
required for hart discovery, halt/resume control, abstract GPR access, and
halted-core abstract memory access.
The target behavior is RISC-V External Debug Specification 0.13.x and eventual
OpenOCD/GDB interoperability.

## 2. Implemented DMI Registers

| Address | Register | Access | Required behavior |
| ---: | --- | --- | --- |
| `0x04` | `data0` | R/W | 32-bit abstract data register 0, used as transfer data |
| `0x05` | `data1` | R/W | 32-bit abstract data register 1, used as Access Memory address |
| `0x10` | `dmcontrol` | R/W | DM activation, hart select, halt/resume, reset control |
| `0x11` | `dmstatus` | R | Version/authentication and selected-hart state |
| `0x12` | `hartinfo` | R | Zero: no hart-local data window or scratch registers |
| `0x16` | `abstractcs` | R/W1C | Two data registers, executor busy, sticky `cmderr` |
| `0x17` | `command` | R/W | Accepted command value and one-cycle executor pulse |

Writes to defined read-only registers must succeed without changing state.
Unsupported addresses and reserved DMI operations must return `FAILED`.

## 3. Single-Hart Contract

Hart 0 is the only implemented hart. `hartsel=0` selects it. Any nonzero
20-bit `hartsel` value reports `anynonexistent=allnonexistent=1` and suppresses
halt, resume, and reset-acknowledge outputs.

For hart 0, each `any*`/`all*` status pair has the same value. The hart supplies
`halted`, `running`, `resumeack`, and `havereset` status inputs.

## 4. Control Requirements

`dmactive` resets low. When inactive, a write that sets `dmactive` must ignore
all other fields in the same write. Clearing `dmactive` resets all Debug Module
control and abstract-command state, but the DMI transport remains responsive.

`haltreq` and `ndmreset` are level outputs. `resumereq` remains asserted until
the selected hart asserts `hart_resumeack_i`. `ackhavereset_o` is a one-cycle
pulse caused by a valid selected-hart acknowledge write. If halt and resume are
requested in the same write, halt takes priority and the resume request clears.

Unsupported `hartreset`, `hasel`, and reset-halt request controls read as zero
and have no side effect.

## 5. Abstract Command Requirements

`abstractcs.datacount` is 2 and `progbufsize` is 0. A command write while the
executor is idle records the command and pulses `command_valid_o` for one
cycle. A command, data0, or data1 write while busy is ignored and sets sticky
`cmderr=BUSY` if no earlier error exists.

Executor errors set sticky `cmderr` only while it is zero. Software clears
selected `cmderr` bits by writing ones to `abstractcs.cmderr`. Executor result
writes update `data0` or `data1` independently of DMI response backpressure.

## 6. DMI Transport Requirements

The block supports one outstanding registered response. It must hold response
status and data stable under backpressure. A new request may be accepted in the
same cycle that the current response is consumed.

## 7. Reset and Implementation Targets

All state uses `clk_i` with asynchronous active-low `rst_ni`. The RTL must be
synthesizable and behaviorally identical for generic simulation, IC, and
Xilinx Virtex-7 FPGA target macros.
