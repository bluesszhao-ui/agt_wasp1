# debug_dmi_if Spec

## 1. Purpose

`debug_dmi_if` is the structured, ready/valid transport between the future
JTAG Debug Transport Module (DTM) and the wasp1 Debug Module (DM).

## 2. Request Channel

The requester drives `req_valid`, `req_op`, `req_addr`, and `req_data`. A
request transfers only when `req_valid && req_ready` is true on a rising
`clk` edge. Request fields must remain stable while valid is asserted and ready
is deasserted.

| Field | Width | Meaning |
| --- | ---: | --- |
| `req_op` | 2 | `NOP=0`, `READ=1`, `WRITE=2`; value 3 is reserved |
| `req_addr` | 7 | Debug Module register address |
| `req_data` | 32 | Write data; ignored by reads and NOPs |

## 3. Response Channel

The responder drives `rsp_valid`, `rsp_resp`, and `rsp_data`. A response
transfers only when `rsp_valid && rsp_ready` is true on a rising edge. Response
fields must remain stable while valid is asserted and ready is deasserted.

| `rsp_resp` | Meaning |
| --- | --- |
| `0` | Success |
| `2` | Failed |
| `3` | Busy |

Only one response is generated for each accepted request. The interface does
not permit request cancellation after a handshake.

## 4. Clock and Reset

Both channels use `clk`. `rst_n` is active low. The implementing endpoint owns
the reset behavior of its valid signals; no transfer is valid during reset.

## 5. Verification Requirements

Verification must cover successful read/write/NOP operations, reserved
operations, response backpressure, stable held responses, and request blocking
while no response capacity is available.
