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
| `ahb_decoder` self-check count | 183 |
| `ahb_default_slave` self-check count | 136 |
| Lint log | `bus/logs/lint.log` |
| Simulation log | `bus/logs/tb_ahb_decoder.log` |

## 2. ahb_decoder Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-1ns | Hold `active_i=0` at zero address | No slave selected | PASS |
| 1ns-16ns | Decode OTP/I-SRAM/D-SRAM base/mid/end/before/after addresses | Matching memory select or default select asserted | PASS |
| 16ns-51ns | Decode DMA/WDG/timer/intc/UART/I2C/GPIO base/mid/end/before/after addresses | Matching peripheral select or adjacent/default select asserted | PASS |
| 51ns-55ns | Decode unmapped low/middle/high/top addresses | Default slave selected | PASS |
| 55ns-183ns | Decode 128 deterministic random addresses | RTL result matches scoreboard model | PASS |
| 183ns-184ns | Hold valid UART address with `active_i=0` | No slave selected | PASS |

## 3. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Inactive decode path | 2 hits |
| OTP select | 3 hits |
| I-SRAM select | 3 hits |
| D-SRAM select | 3 hits |
| DMA select | 3 hits |
| WDG select | 3 hits |
| timer select | 3 hits |
| intc select | 3 hits |
| UART select | 3 hits |
| I2C select | 3 hits |
| GPIO select | 3 hits |
| Default select | 151 hits |
| One-hot select check | PASS for every active decode |
| Scoreboard random check | 128 deterministic random addresses |

## 4. Notes

The decoder currently uses these default memory sizes from `wasp1_pkg`:

```text
OTP_SIZE   = 0x0001_0000
ISRAM_SIZE = 0x0001_0000
DSRAM_SIZE = 0x0001_0000
```

These are initial parameters, not final capacity decisions.

## 5. ahb_default_slave Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-2ns | Drive unselected IDLE and NONSEQ transfers | HRESP OKAY, HREADY high, HRDATA zero | PASS |
| 2ns-4ns | Drive selected IDLE and BUSY transfers | HRESP OKAY, HREADY high, HRDATA zero | PASS |
| 4ns-8ns | Drive selected NONSEQ/SEQ read/write transfers | HRESP ERROR, HREADY high, HRDATA zero | PASS |
| 8ns-136ns | Drive 128 deterministic random transfers | RTL response matches scoreboard model | PASS |

## 6. ahb_default_slave Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 136 |
| ERROR response path | 39 hits |
| OKAY response path | 97 hits |
| Read path | 70 hits |
| Write path | 66 hits |
| Byte size | 43 hits |
| Halfword size | 47 hits |
| Word size | 46 hits |
| HREADY always high check | PASS for every case |
| HRDATA zero check | PASS for every case |
| Scoreboard random check | 128 deterministic random transfers |
