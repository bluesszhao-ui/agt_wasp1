# debug_jtag_dtm Design Spec

## 1. Scope

`debug_jtag_dtm` implements a stage-1 RISC-V JTAG DTM around the existing
wasp1 `debug_dmi_if`. The implementation is split into a JTAG `tck_i` domain
and a system `clk_i` domain.

## 2. Block Diagram

Editable OmniGraffle source is planned for this figure under
`debug/docs/diagrams/debug_jtag_dtm_block.graffle`. Until that source is added,
the text diagram below is the diff-friendly engineering contract.

```text
 IF JTAG pins
 tck_i/trst_ni/tms_i/tdi_i/tdo_o
        |
        v
+-------------------------+       +-------------------------+
| SEQ clk=tck_i           |       | COMB                    |
| rst=trst_ni/rst_ni      |------>| TAP next-state decode   |
| TAP FSM state           |       | IR/DR decode mux        |
+-----------+-------------+       +------------+------------+
            |                                  |
            v                                  v
+-------------------------+       +-------------------------+
| SEQ clk=tck_i           |<----->| COMB                    |
| rst=trst_ni/rst_ni      |       | DTMCS/DMI capture data  |
| IR and DR shift regs    |       | DR width select         |
+-----------+-------------+       +------------+------------+
            |                                  |
            v                                  v
+-------------------------+       +-------------------------+
| SEQ clk=tck_i           |       | IF CDC request payload  |
| rst=trst_ni/rst_ni      |------>| req_toggle + stable bus |
| DMI request launch      |       +------------+------------+
| sticky dmistat          |                    |
+-----------+-------------+                    v
            ^                       +-------------------------+
            |                       | SEQ clk=clk_i rst=rst_ni|
            |                       | DMI req/rsp sequencer   |
            |                       +------------+------------+
            |                                    |
            |                                    v
            |                       IF debug_dmi_if.dtm
            |                                    |
            |                       +------------+------------+
            |                       | IF CDC response payload |
            +-----------------------| rsp_toggle + stable bus |
                                    +-------------------------+
```

Timing classes:

```text
IF   external pins, internal interface, or CDC payload boundary
SEQ  sequential state/storage with explicit clock/reset
COMB combinational decode, mux, or next-state logic
```

## 3. TAP FSM

The TAP controller implements all 16 IEEE 1149.1 states:

```text
TEST_LOGIC_RESET
RUN_TEST_IDLE
SELECT_DR_SCAN
CAPTURE_DR
SHIFT_DR
EXIT1_DR
PAUSE_DR
EXIT2_DR
UPDATE_DR
SELECT_IR_SCAN
CAPTURE_IR
SHIFT_IR
EXIT1_IR
PAUSE_IR
EXIT2_IR
UPDATE_IR
```

Transition conditions are the standard JTAG `tms_i` transitions. Reset through
`trst_ni` or `rst_ni` forces `TEST_LOGIC_RESET`; remaining in
`TEST_LOGIC_RESET` with `tms_i=1` also resets the active IR to `IDCODE` and
clears sticky DMI status.

## 4. IR and DR Implementation

`IR_WIDTH` defaults to five bits. `CAPTURE_IR` loads the required low-bit
pattern `2'b01`. `SHIFT_IR` shifts LSB-first and `UPDATE_IR` commits the active
instruction.

The DR shift register is physically sized to the largest supported scan chain,
but the insertion point changes by active instruction:

| Active IR | Shift width | TDI insertion bit |
| --- | ---: | ---: |
| `IDCODE` | 32 | 31 |
| `DTMCS` | 32 | 31 |
| `DMI` | `DMI_ADDR_WIDTH + 34` | 40 for the default 7-bit address width |
| `BYPASS`/unsupported | 1 | 0 |

This avoids corrupting shorter scan chains when the DMI chain is wider than
32 bits.

## 5. DMI CDC Sequencer

The CDC is a single-entry toggle handshake:

| Direction | Producer domain | Consumer domain | Stable payload |
| --- | --- | --- | --- |
| request | `tck_i` | `clk_i` | `req_op_tck_q`, `req_addr_tck_q`, `req_data_tck_q` |
| response | `clk_i` | `tck_i` | `rsp_addr_clk_q`, `rsp_data_clk_q`, `rsp_resp_clk_q` |

When a DMI scan updates with `READ` or `WRITE`, the TCK domain latches the
payload, toggles `req_toggle_tck_q`, and marks the request busy. The `clk_i`
domain synchronizes the toggle, captures the stable payload, asserts
`dmi.req_valid`, waits for `dmi.req_ready`, then waits for `dmi.rsp_valid`.
After capturing the response it toggles `rsp_toggle_clk_q`. The TCK domain
synchronizes that response toggle, clears busy, and makes the response visible
to the next DMI scan.

## 6. Priority and Side Effects

Priority in the TCK domain:

| Priority | Event | Side effect |
| ---: | --- | --- |
| 1 | `trst_ni=0` or `rst_ni=0` | Reset TAP, IR, sticky status, request launch state. |
| 2 | response toggle observed | Capture response, clear busy, set sticky failed if needed. |
| 3 | TAP reset state | Select `IDCODE`, clear sticky status. |
| 4 | `UPDATE_DR` with `DTMCS.dmireset`/`dmihardreset` | Clear sticky status; optionally pulse hard reset. |
| 5 | `UPDATE_DR` with non-NOP `DMI` | Launch request if idle; otherwise return/set busy. |

Priority in the `clk_i` domain:

| Priority | Event | Side effect |
| ---: | --- | --- |
| 1 | `rst_ni=0` | Clear request/response sequencer. |
| 2 | new request toggle while idle | Capture stable request payload and assert `dmi.req_valid`. |
| 3 | `dmi.req_valid && dmi.req_ready` | Drop request valid and wait for response. |
| 4 | `dmi_rsp_wait_q && dmi.rsp_valid` | Capture response and toggle completion. |

## 7. State Diagram Requirement

This module has a non-trivial protocol FSM and CDC sequence. The design-spec
figure should be maintained as an L3 editable OmniGraffle diagram with:

```text
TAP reset and all 16 TAP states
DMI request launch/busy/complete path
DTMCS sticky status clear path
clk_i-domain request/response sequencer
```

The Markdown state and priority tables above remain the reviewable textual
contract for transitions and side effects.
