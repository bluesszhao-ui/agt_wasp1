# frontend_ibuf Verification Report

## 1. Result

Status: PASS.

## 2. Testbench

```text
testbench: frontend/tb/tb_frontend_ibuf.sv
filelist:  frontend/filelists/tb_frontend_ibuf.f
target:    make -C frontend sim-frontend-ibuf
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Hold reset active. | FIFO is empty; no pop response is valid. | PASS: empty state matched. |
| 20ns-30ns | Release reset. | FIFO remains empty and ready for push. | PASS: reset release matched. |
| 30ns-50ns | Push two entries. | Entries are accepted; FIFO reaches full. | PASS: full state matched. |
| 50ns-60ns | Attempt a third push while full. | Push is blocked; oldest two entries remain queued. | PASS: blocked push matched. |
| 60ns-70ns | Pop first entry. | First pushed entry appears and is consumed. | PASS: first pop matched. |
| 70ns-80ns | Push and pop simultaneously. | Second pushed entry is popped; new entry is queued. | PASS: simultaneous push/pop matched. |
| 80ns-90ns | Pop queued metadata entry. | Misaligned/fault metadata matches reference queue. | PASS: metadata matched. |
| 90ns-120ns | Push two entries, then assert flush with push/pop intent. | FIFO clears; push and pop are suppressed during flush. | PASS: flush priority matched. |
| 120ns-917ns | Run 80 deterministic-random cycles. | Reference queue matches every cycle. | PASS: all random cycles matched. |

## 4. Coverage Summary

```text
tb_frontend_ibuf coverage: pass_count=91 push=32 pop=16 full=1 empty=3 flush=14 simultaneous=7 fault=2 random=80
tb_frontend_ibuf PASS
```

## 5. Commands

Executed:

```text
make -C frontend sim-frontend-ibuf
```

Full milestone validation is tracked with the current commit:

```text
make -C frontend lint
make -C frontend lint-ic
make -C frontend lint-fpga-v7
make -C frontend sim
make lint
```
