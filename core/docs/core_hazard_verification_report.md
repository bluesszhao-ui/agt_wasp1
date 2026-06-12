# core_hazard Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```sh
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim-core-hazard
make -C core sim
make lint
```

## 3. Time/Cycle Action Table

| Time | Cycle Window | Action | Result |
| --- | --- | --- | --- |
| 0ns-1ns | Idle | No dependency | No stall or forwarding asserted |
| 1ns-5ns | Forwarding | EX and WB forwarding for rs1/rs2 | EX forwarding and WB forwarding selected as expected |
| 5ns-7ns | Load-use | rs1/rs2 execute-load hazards | Fetch/decode stall and execute bubble asserted |
| 7ns-10ns | x0/priority/gating | x0 suppression, EX priority, invalid decode slot | x0 ignored, EX wins over WB, invalid decode suppresses hazards |
| 10ns-210ns | Random | 200 deterministic random dependency checks | All checks matched the reference model |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_hazard coverage: pass_count=210 ex=2 wb=2 stall=2 x0=1 priority=1 random=200
tb_core_hazard PASS
```

Coverage intent met:

- EX forwarding for both decode sources.
- WB forwarding for both decode sources.
- Load-use stalls for both decode sources.
- x0 hazard suppression.
- EX-over-WB priority.
- Invalid decode gating.
- 200 deterministic random dependency checks.
