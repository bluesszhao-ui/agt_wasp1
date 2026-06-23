# debug DMI Register Verification Plan

## 1. Goals

Verify the stage-1 DMI transport and register file before adding the JTAG DTM,
hart-control executor, or abstract GPR engine.

## 2. Directed Cases

| Phase | Action | Expected result |
| --- | --- | --- |
| Reset | Assert `rst_ni=0` for three clocks | DM state and response valid clear |
| Identity | Read inactive `dmstatus` | version 2 and authenticated are visible |
| Activation | Set `dmactive` with other fields set | only `dmactive` changes |
| Control | Set halt, resume, and ndmreset | level requests follow documented semantics |
| Resume | Assert hart resume acknowledgement | held resume request clears |
| Pulse | Write ackhavereset | exactly one pulse occurs |
| Status | Drive running/halted/reset/resume states | matching any/all fields are returned |
| Enumeration | Select hart 1 | nonexistent fields assert and requests suppress |
| Abstract data | DMI and executor write `data0` | reads return the latest accepted value |
| Busy | Write command while executor busy | command ignored and `cmderr=BUSY` |
| W1C | Clear `cmderr` through abstractcs | selected error bits clear |
| Command | Write command while idle | command captured and one pulse occurs |
| Executor error | Inject unsupported-command error | first error becomes sticky |
| Read-only | Write dmstatus | operation succeeds with no state change |
| Error | Use unknown address and reserved operation | DMI response is `FAILED` |
| Backpressure | Hold `rsp_ready=0` | response stable and new requests blocked |
| Random | Write/read 16 deterministic random data0 values | every value compares exactly |
| Deactivation | Clear dmactive | all DM-owned state returns to reset values |

## 3. Coverage Intent

Coverage counters must report reads, writes, status classes, one-cycle pulses,
busy handling, failed accesses, backpressure observations, and random data
iterations. Every test is self-checking and terminates immediately on mismatch.

## 4. Target Matrix

| Target | Command | Expected result |
| --- | --- | --- |
| Generic simulation | `make -C debug lint` | PASS |
| IC | `make -C debug lint-ic` | PASS |
| Xilinx Virtex-7 | `make -C debug lint-fpga-v7` | PASS |
| Functional simulation | `make -C debug sim` | PASS |
