# frontend_ibuf Verification Plan

## 1. Verification Scope

Verify FIFO ordering, status flags, push/pop handshakes, full and empty
behavior, simultaneous push/pop behavior, flush priority, metadata preservation,
and deterministic-random traffic.

## 2. Testbench

```text
testbench: frontend/tb/tb_frontend_ibuf.sv
filelist:  frontend/filelists/tb_frontend_ibuf.f
target:    make -C frontend sim-frontend-ibuf
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Coverage Goals

| Goal | Method |
| --- | --- |
| Reset/empty | Check empty status and no pop-valid during and after reset. |
| Ordered push/pop | Push multiple entries and compare popped payload against a reference queue. |
| Full behavior | Fill the two-entry FIFO and verify push backpressure. |
| Push blocked when full | Attempt an extra push while full and verify reference queue is unchanged. |
| Simultaneous push/pop | Pop oldest entry while accepting a new entry. |
| Metadata preservation | Check fault and misaligned flags through the FIFO. |
| Flush priority | Assert flush with push and pop intent and verify all queued entries are dropped. |
| Random handshakes | Run 80 deterministic-random push/pop/flush cycles. |

## 4. Time-Sequenced Case Plan

| Time window | Action | Expected result |
| --- | --- | --- |
| 0ns-20ns | Hold reset active. | FIFO is empty; no pop response is valid. |
| 20ns-30ns | Release reset. | FIFO remains empty and ready for push. |
| 30ns-50ns | Push two entries. | Entries are accepted; FIFO reaches full. |
| 50ns-60ns | Attempt a third push while full. | Push is blocked; oldest two entries remain queued. |
| 60ns-70ns | Pop first entry. | First pushed entry appears and is consumed. |
| 70ns-80ns | Push and pop simultaneously. | Second pushed entry is popped; new entry is queued. |
| 80ns-90ns | Pop queued metadata entry. | Misaligned/fault metadata matches reference queue. |
| 90ns-120ns | Push two entries, then assert flush with push/pop intent. | FIFO clears; push and pop are suppressed during flush. |
| 120ns-917ns | Run 80 deterministic-random cycles. | Reference queue matches every cycle. |

## 5. Pass Criteria

Simulation must finish with `tb_frontend_ibuf PASS`, all self-checks passing,
and minimum counters for total checks, pushes, pops, full, empty, flush,
simultaneous push/pop, metadata, and random coverage.
