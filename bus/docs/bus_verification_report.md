# bus Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-10 |
| Tool | Verilator 5.046 |
| Lint command | `make -C bus lint` |
| Simulation command | `make -C bus sim` |
| Lint result | PASS |
| Simulation result | PASS |
| Lint log | `bus/logs/lint.log` |
| Simulation log | `bus/logs/tb_ahb_decoder.log` |

## 2. ahb_decoder Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-1ns | Hold `active_i=0` | No slave selected | PASS |
| 1ns-2ns | Decode OTP base and end address | `AHB_SLAVE_OTP` selected | PASS |
| 2ns-3ns | Decode I-SRAM base and end address | `AHB_SLAVE_ISRAM` selected | PASS |
| 3ns-4ns | Decode D-SRAM base and end address | `AHB_SLAVE_DSRAM` selected | PASS |
| 4ns-14ns | Decode DMA/WDG/timer/intc/UART/I2C/GPIO regions | Matching peripheral selected | PASS |
| 14ns-16ns | Decode unmapped high address and OTP boundary | Default slave selected | PASS |
| 16ns-18ns | Hold valid address with `active_i=0` | No slave selected | PASS |

## 3. Notes

The decoder currently uses these default memory sizes from `wasp1_pkg`:

```text
OTP_SIZE   = 0x0001_0000
ISRAM_SIZE = 0x0001_0000
DSRAM_SIZE = 0x0001_0000
```

These are initial parameters, not final capacity decisions.
