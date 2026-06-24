# debug_reg_access Verification Plan

## 1. Goals

Verify one-outstanding GPR transport, stable ready/valid behavior, error
propagation, and cancellation safety before abstract-command decoding and core
Debug Mode integration.

## 2. Directed Cases

| Case | Expected result |
| --- | --- |
| Reset | idle, command ready, no request/response valid |
| Read | address held; returned data forwarded exactly |
| Write | write/address/data held; completion returned |
| Request backpressure | all core request fields remain stable |
| Delayed response | core response ready stays asserted in wait |
| Upstream backpressure | local response data/error remain stable |
| Same-cycle response | request acceptance captures simultaneous response |
| Core error | response error propagates with its data |
| Flush before request acceptance | request suppressed and command discarded |
| Flush while waiting | sequencer enters drain state and blocks new commands |
| Flush with response | stale response consumed without local response |
| Flush local response | pending upstream response discarded |
| Reset while busy | sequencer immediately returns to reset contract |
| Random | 20 deterministic read/write/error/latency combinations compare |

## 3. Coverage Counters

The testbench reports read/write, request-held cycles, response-held cycles,
same-cycle response, core error, flush class, stale drain, reset-abort, and
random transaction counts.

## 4. Target Matrix

Generic, IC, and Virtex-7 lint plus the complete debug simulation aggregate
must pass before commit.
