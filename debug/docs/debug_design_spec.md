# debug Design Spec

## 1. Scope

`debug` structurally integrates the verified stage-1 Debug Module leaves:

```text
debug_dmi_regs
debug_halt_ctrl
debug_abstract_cmd
debug_reg_access
debug_progbuf_exec
```

`debug_progbuf` storage is owned by `debug_dmi_regs`, which routes four DMI
words to `debug_progbuf_exec`. Access Register postexec keeps abstract busy,
sequences words to the core execution channel, consumes EBREAK locally, and
returns executor cmderr. The wrapper advertises `abstractcs.progbufsize=4`.

The wrapper adds no new architectural register state. Its local logic consists
of explicit channel wiring, top-level output assignment, and an internal
abstract-access `debug_if` instance used to satisfy leaf modport ownership.

Editable source: `debug/docs/diagrams/debug_block.graffle`
Generator: `debug/dv/generate_debug_block_diagram.py`
Detail level: L3; clock domain: `clk_i/rst_ni` on every SEQ block.

## 2. Block Diagram

```text
       IF DMI from JTAG DTM wrapper
              |
              v
   +------------------------+
   | SEQ clk_i rst_ni       |
   | debug_dmi_regs         |
   | DMI regs/response slot |
   +-----+-------------+----+
         | halt/resume    | command/data0/cmderr    | progbuf0..3
         v                v                         v
+----------------+  +-----------------------+  +-----------------------+
| SEQ clk_i      |  | SEQ clk_i rst_ni      |  | SEQ clk_i rst_ni     |
| debug_halt_ctrl|  | debug_abstract_cmd    |  | debug_progbuf_exec   |
| hart request   |  | transfer/postexec FSM |->| ordered instruction  |
| sticky status  |  +-----------+-----------+  | execution FSM        |
+-------+--------+              |              +-----------+-----------+
        |                       | decoded GPR              |
        v                       v                          v
 IF core_debug           +----------------------+   IF core_debug execute
 halt/resume/status      | SEQ clk_i rst_ni     |   request/response
                         | debug_reg_access     |
                         | GPR ready/valid FSM  |
                         +----------+-----------+
                                    |
                                    v
                            IF core_debug GPR
```

Timing-class labels:

```text
IF   external or structured interface connection
SEQ  sequential leaf or state, clk=clk_i, rst=rst_ni
```

## 3. Internal Connectivity

`debug_dmi_regs` owns the architectural DMI register contract. Its outputs
drive:

```text
dmactive/resumereq/haltreq/ackhavereset -> debug_halt_ctrl
command_valid/command/data0             -> debug_abstract_cmd
```

`debug_halt_ctrl` observes `core_debug.halted`, `core_debug.running`, and
`hart_reset_event_i`. It drives:

```text
core_debug.halt_req
core_debug.resume_req
hart_halted/hart_running/hart_resumeack/hart_havereset back to debug_dmi_regs
```

`debug_abstract_cmd` decodes the command register and drives one decoded GPR
transaction into `debug_reg_access`. It also consumes `core_debug.dpc` for
abstract CSR reads of `dpc`, consumes `core_debug.dcsr_cause` for `dcsr`
readback, owns the local `dcsr.step` bit and two trigger CSR images, and
returns successful read data or cmderr updates to `debug_dmi_regs`.

For Access Register `postexec`, `debug_abstract_cmd` pulses
`debug_progbuf_exec.start_i` only after any required transfer succeeds. The
executor reads the parallel Program Buffer image, issues one word at a time on
`core_debug.exec_req_*`, waits for `core_debug.exec_rsp_*`, and consumes an
explicit EBREAK locally. Completion error returns to the same abstract command
before `abstract_busy` clears.

Single-step is a small wrapper-level combinational path:

```text
core_debug.step_req = core_resume_req && dcsr_step
```

This means a normal resume request remains unchanged while `dcsr.step=0`.
When `dcsr.step=1`, the core-side `core_debug_ctrl` receives both resume and
step for one resume transaction and re-enters halted state after one
retirement.

The trigger output path is wrapper-level combinational after the trigger CSR
registers:

```text
core_debug.trigger_execute_valid[slot] = selected trigger slot enables legal mcontrol execute match
core_debug.trigger_execute_addr[slot]  = selected trigger slot tdata2 compare address
core_debug.trigger_load_valid[slot]    = selected trigger slot enables legal mcontrol load match
core_debug.trigger_store_valid[slot]   = selected trigger slot enables legal mcontrol store match
core_debug.trigger_data_addr[slot]     = selected trigger slot tdata2 compare address
```

The core performs ID-stage PC compares for execute triggers and EX-stage
effective-address compares for load/store triggers. A matched architectural
memory operation is blocked before request issue, retirement, alignment fault,
or response fault; the core enters Debug Mode with the matched PC in DPC and
reports the trigger DCSR cause through `core_debug.dcsr_cause`. The core
datapath verification report owns coverage of that downstream behavior.

`debug_reg_access` uses an internal `debug_if` instance with the `dm_gpr`
modport. The wrapper explicitly bridges only GPR request/response signals to
the full `core_debug` top port. This avoids giving the GPR sequencer ownership
of halt/resume/step controls.

## 4. Sequential State

The top wrapper has no named FSM. Sequential behavior is inherited from:

| Leaf | Sequential role |
| --- | --- |
| `debug_dmi_regs` | DMI response slot, dmcontrol, data0, command, cmderr |
| `debug_halt_ctrl` | Halt/resume transaction FSM, resumeack/havereset sticky bits |
| `debug_abstract_cmd` | Abstract command issue/wait/complete FSM |
| `debug_reg_access` | Core GPR request/wait/local-response/drop-response FSM |
| `debug_progbuf_exec` | Program Buffer check/issue/wait/complete FSM |

The wrapper-level state diagram is therefore the leaf FSM composition rather
than a new independent machine.

## 5. Reset and Priority

All instantiated leaves share `clk_i/rst_ni`. Asserting reset returns DMI
transport, hart control, abstract command, and GPR access state to each leaf's
documented reset value. `hart_reset_event_i` is synchronous and only affects the
halt-control sticky status and outstanding halt/resume transaction.

## 6. Target Behavior

Target macros are included through child RTL and do not alter the wrapper
connectivity or the DMI/core-debug behavioral contract.
