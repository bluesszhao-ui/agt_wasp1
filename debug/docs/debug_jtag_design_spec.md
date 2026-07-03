# debug_jtag Design Spec

## 1. Scope

`debug_jtag` structurally composes:

```text
debug_jtag_dtm
debug
debug_dmi_if dmi_link
```

It is the first integrated JTAG-to-Debug-Module boundary and prepares the debug
subsystem for later SoC pin-level integration.

## 2. Block Diagram

Editable OmniGraffle source is planned under
`debug/docs/diagrams/debug_jtag_block.graffle`. Until that source is added, the
text diagram below is the diff-friendly engineering contract.

```text
 IF JTAG pins
 tck_i/trst_ni/tms_i/tdi_i/tdo_o
        |
        v
+----------------------------+
| SEQ clk=tck_i              |
| rst=trst_ni/rst_ni         |
| debug_jtag_dtm TAP/scan    |
+-------------+--------------+
              |
              | IF debug_dmi_if.dtm
              | clk=clk_i rst=rst_ni
              v
+----------------------------+
| IF dmi_link                |
| ready/valid DMI channel    |
+-------------+--------------+
              |
              | IF debug_dmi_if.dm
              v
+----------------------------+
| SEQ clk=clk_i rst=rst_ni   |
| debug Debug Module wrapper |
| regs/halt/abstract/GPR     |
+-------------+--------------+
              |
              v
 IF core_debug to single hart
```

Timing classes:

```text
IF   external or structured interface connection
SEQ  sequential child module or storage, with explicit clock/reset
```

`debug_jtag` itself contains no `always_ff` or `always_comb` blocks.

## 3. Internal Connectivity

`debug_jtag_dtm` drives the internal `dmi_link` with its `dtm` modport. `debug`
consumes the same interface through its `dm` modport. Both sides use `clk_i` and
`rst_ni` for the ready/valid DMI link.

The JTAG TAP and DMI scan registers remain in `debug_jtag_dtm`. The Debug Module
architectural registers and hart-control state remain in `debug`.

## 4. Reset Behavior

`rst_ni` resets both the DTM DMI sequencer and the Debug Module. `trst_ni`
resets the JTAG TAP and scan state. `debug_jtag` does not add reset sequencing
or reset filtering.

## 5. Sequential State

No wrapper-local sequential state exists. Sequential behavior is inherited from:

| Child | Clock/reset | State role |
| --- | --- | --- |
| `debug_jtag_dtm` | `tck_i/trst_ni/rst_ni` and `clk_i/rst_ni` | TAP FSM, IR/DR scan registers, DMI CDC sequencer |
| `debug` | `clk_i/rst_ni` | Debug Module registers, halt/resume FSM, abstract command and GPR access FSMs |

## 6. Integration Priority

There is no arbitration inside this wrapper. The only DMI master is
`debug_jtag_dtm`, and the only DMI target is `debug`.
