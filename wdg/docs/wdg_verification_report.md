# wdg Verification Report

## 1. Commands

```text
make -C wdg lint
make -C wdg lint-ic
make -C wdg lint-fpga-v7
make -C wdg sim
```

## 2. Results

| Check | Result |
| --- | --- |
| Generic lint | PASS |
| IC-target lint | PASS |
| Virtex-7-target lint | PASS |
| `tb_ahb_wdg` simulation | PASS |

Simulation coverage counters:

```text
pass_count=50
reg_count=35
timeout_count=2
kick_count=2
error_count=5
random_count=4
```

## 3. Time-Sequenced Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-35ns | Reset asserted for three 10ns clock cycles, then released | HREADY high, HRESP OKAY, HRDATA zero, IRQ/reset low | PASS |
| 35ns-115ns | Read CTRL, STATUS, TIMEOUT, COUNT reset values | Reset register values match spec | PASS |
| 115ns-235ns | Program timeout 4, enable IRQ/reset, read CTRL/STATUS | CTRL readback `0x7`, STATUS running bit set | PASS |
| 235ns-275ns | Let watchdog run for timeout window | Expired, IRQ, and reset request assert | PASS |
| 275ns-395ns | Write correct KICK key, read count, kick again before expiry | Expired/reset clear and timeout is prevented | PASS |
| 395ns-545ns | Clear, set longer timeout, write bad KICK key, read status | Key error set, watchdog not fed | PASS |
| 545ns-655ns | Clear status, enable reset-only timeout | Reset request asserts while IRQ remains masked | PASS |
| 655ns-755ns | Misaligned, halfword, unknown, and out-of-range accesses | All return AHB ERROR | PASS |
| 755ns-1000ns | Four deterministic random timeout tests | IRQ asserts after each programmed timeout | PASS |

## 4. Residual Risk

The module is single-clock and always-ready, so no backpressure-specific cases
apply. Integration-level reset propagation from `wdg_reset_req_o` into the SoC
reset tree remains a top-level `wasp1` verification item.
