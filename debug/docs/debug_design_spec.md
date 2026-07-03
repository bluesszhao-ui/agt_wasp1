# debug Design Spec

## 1. Scope

`debug` structurally integrates the verified stage-1 Debug Module leaves:

```text
debug_dmi_regs
debug_halt_ctrl
debug_abstract_cmd
debug_reg_access
```

The wrapper adds no new architectural register state. Its local logic consists
of explicit channel wiring, top-level output assignment, and an internal
GPR-only `debug_if` instance used to satisfy leaf modport ownership.

## 2. Block Diagram

```text
       IF DMI from future JTAG DTM
              |
              v
   +------------------------+
   | SEQ clk_i rst_ni       |
   | debug_dmi_regs         |
   | DMI regs/response slot |
   +-----+-------------+----+
         |             |
         | halt/resume | command/data0/cmderr
         v             v
+----------------+   +-----------------------+
| SEQ clk_i      |   | SEQ clk_i rst_ni      |
| debug_halt_ctrl|   | debug_abstract_cmd    |
| hart request   |   | Access Register decode|
| sticky status  |   +-----------+-----------+
+-------+--------+               |
        |                        | decoded GPR command
        v                        v
 IF core_debug             +----------------------+
 halt/resume/status        | SEQ clk_i rst_ni     |
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
transaction into `debug_reg_access`. It returns successful read data or cmderr
updates to `debug_dmi_regs`.

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
