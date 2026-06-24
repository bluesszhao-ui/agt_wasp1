# debug_reg_access Spec

## 1. Purpose

`debug_reg_access` transfers one decoded Debug Module GPR command to the halted
core through the GPR subset of `debug_if`, then returns one response upstream.
It does not decode RISC-V abstract-command bit fields.

## 2. Upstream Command Contract

A command transfers when `cmd_valid_i && cmd_ready_o` is true on a rising
`clk_i` edge. The command contains read/write direction, a five-bit x0-x31
address, and 32-bit write data. Only one command may be outstanding.

The sequencer must capture command fields and hold the core request unchanged
until the core accepts it.

## 3. Core GPR Contract

The core request and response channels use independent ready/valid handshakes.
The sequencer must support:

```text
request backpressure
delayed core response
response on the same edge as request acceptance
core access error
```

The core owns architectural x0 behavior and rejection of accesses made outside
Debug Mode.

## 4. Upstream Response Contract

Every non-flushed command produces exactly one upstream response. Response data
and error must remain stable while `rsp_valid_o && !rsp_ready_i`.

## 5. Flush Contract

`flush_i` prevents acceptance of a new command and suppresses an unaccepted
core request immediately.

If the core already accepted a request, flush must discard the corresponding
response. The sequencer must remain unavailable until that stale response is
consumed, preventing it from being paired with a later command.

Flush while an upstream response is pending discards that response and returns
the sequencer to idle.

## 6. Reset and Targets

All state uses `clk_i` and asynchronous active-low `rst_ni`. Reset returns the
sequencer to idle. Behavior must be identical for generic simulation, IC, and
Xilinx Virtex-7 FPGA targets.

## 7. Verification Requirements

Verification must cover read/write, request/response backpressure, same-cycle
response, core error, every flush phase, stale-response draining, reset, stable
held fields, and deterministic-random transactions.
