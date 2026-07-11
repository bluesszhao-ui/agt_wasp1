# wasp1 Verification Plan

## 1. Verification Goals

Verification is module-first and integration-second. Each first-level module is
verified in isolation before it is integrated into the SoC.

The goal is high functional coverage through directed tests, protocol checks,
randomized stimulus where useful, and end-to-end software tests.

## 2. Per-Module Deliverables

Each hardware module should provide:

| Deliverable | Location |
| --- | --- |
| Design spec | `module/docs/` |
| Verification plan | `module/docs/` |
| Testbench | `module/tb/` |
| Verification helpers | `module/dv/` |
| Source filelist | `module/filelists/` |
| Build output | `module/build/` |
| Logs | `module/logs/` |
| Waveforms | `module/wave/` |

## 3. Required Verification Case Table Format

Each verification document must include a table like this:

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Apply reset | All state reaches reset value | TBD |
| 20ns-60ns | Drive first transaction | DUT accepts request | TBD |
| 60ns-100ns | Check response | Response matches expected value | TBD |

Default simulation timebase:

```text
`timescale 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

Pure combinational modules may be checked without a DUT clock, but the
verification document should state that explicitly. When practical, combinational
testbenches should still group checks into 10ns verification steps so reports
remain consistent with clocked modules.

## 4. Protocol Checks

AHB-Lite modules require checks for:

```text
valid address phase behavior
stable control while stalled
correct HREADY handling
correct HRESP generation
aligned transfer behavior
byte lane write behavior
default slave error behavior
```

Internal request-response interfaces require checks for:

```text
valid/ready stability
no response without request
no dropped request under backpressure
correct response ordering
```

## 5. System Tests

Full SoC simulations should include:

```text
reset from OTP
UART hello program
timer interrupt
GPIO interrupt
DMA memory copy
OTP programming routine running from I-SRAM
I-cache refill from OTP
D-cache load/store to D-SRAM
OpenOCD/GDB debug attach, breakpoint, and load/store watchpoint tests
```

## 6. Coverage Intent

Initial coverage is functional coverage documented in the verification plan.
When the simulator supports it, SystemVerilog covergroups and assertions should
be added for protocol and state machine coverage.
