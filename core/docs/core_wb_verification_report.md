# core_wb Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```sh
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim-core-wb
make -C core sim
make lint
```

## 3. Time/Cycle Action Table

| Time | Cycle Window | Action | Result |
| --- | --- | --- | --- |
| 0ns-1ns | Init | Initialize candidate data and controls | Stable defaults observed |
| 1ns-6ns | Source mux | ALU/load/CSR/PC+4/immediate source checks | All selected values matched reference model |
| 6ns-10ns | Suppression | Invalid, no-write, trap, and fault suppression checks | Write enable suppressed as expected |
| 10ns-11ns | x0 | Suppress write to x0 | Write enable suppressed for rd=x0 |
| 11ns-12ns | Default | Unknown selector defaults to ALU result | ALU result selected |
| 12ns-212ns | Random | 200 deterministic random writeback checks | All checks matched the reference model |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_wb coverage: pass_count=211 source=5 suppress=4 x0=1 default=1 random=200
tb_core_wb PASS
```

Coverage intent met:

- All five writeback sources.
- Invalid, no-write, trap, and fault suppression.
- x0 suppression.
- Default selector fallback.
- 200 deterministic random checks.
