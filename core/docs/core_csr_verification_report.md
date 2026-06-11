# core_csr Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```sh
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim
```

## 3. Time/Cycle Action Table

| Time | Cycle Window | Action | Result |
| --- | --- | --- | --- |
| 0ns-35ns | Reset | Reset CSR file and idle inputs | PASS |
| 35ns-42ns | Reset reads | Read reset values of writable CSRs | PASS |
| 42ns-122ns | CSR ops | RW/RS/RC/RWI and masked CSR writes | PASS |
| 122ns-132ns | IRQ | Enable and drive timer/external pending inputs | PASS |
| 132ns-152ns | Counters | Check cycle and instret increments | PASS |
| 152ns-192ns | Trap/MRET | Trap entry and MRET restore checks | PASS |
| 192ns-199ns | Illegal | Read-only and unsupported CSR illegal checks | PASS |

## 4. Coverage Summary

```text
pass_count=38
rw=6
set_clear=2
readonly=4
trap=2
counter=2
irq=2
```

All planned cases passed.
