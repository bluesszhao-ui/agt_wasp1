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
| `ahb_slave_mux` self-check count | 144 |
| Lint log | `bus/logs/lint.log` |
| Simulation log | `bus/logs/tb_ahb_decoder.log` |

## 2. Simulation Timebase

The current `ahb_decoder` is pure combinational and its testbench does not drive
a DUT clock.

`ahb_default_slave` has AHB-style `hclk_i` and `hresetn_i` ports for interface
consistency. Its current response logic is still zero-wait combinational, but
the testbench drives a 10ns clock and samples once per verification cycle.

The verification tables below use ordered simulation check windows. These are
not clock cycles. The project default for clocked modules is:

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. ahb_decoder Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Check 0 | Hold `active_i=0` at zero address | No slave selected | PASS |
| Checks 1-15 | Decode OTP/I-SRAM/D-SRAM base/mid/end/before/after addresses | Matching memory select or default select asserted | PASS |
| Checks 16-50 | Decode DMA/WDG/timer/intc/UART/I2C/GPIO base/mid/end/before/after addresses | Matching peripheral select or adjacent/default select asserted | PASS |
| Checks 51-54 | Decode unmapped low/middle/high/top addresses | Default slave selected | PASS |
| Checks 55-182 | Decode 128 deterministic random addresses | RTL result matches scoreboard model | PASS |
| Check 183 | Hold valid UART address with `active_i=0` | No slave selected | PASS |

## 4. ahb_decoder Functional Coverage Summary

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

## 5. Notes

The decoder currently uses these default memory sizes from `wasp1_pkg`:

```text
OTP_SIZE   = 0x0001_0000
ISRAM_SIZE = 0x0001_0000
DSRAM_SIZE = 0x0001_0000
```

These are initial parameters, not final capacity decisions.

## 6. ahb_default_slave Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-2 | Assert reset for two cycles | Inputs initialized, no error response required | PASS |
| Cycle 3 | Release reset and settle for one cycle | DUT ready for checks | PASS |
| Cycles 4-5 | Drive unselected IDLE and NONSEQ transfers | HRESP OKAY, HREADY high, HRDATA zero | PASS |
| Cycles 6-7 | Drive selected IDLE and BUSY transfers | HRESP OKAY, HREADY high, HRDATA zero | PASS |
| Cycles 8-11 | Drive selected NONSEQ/SEQ read/write transfers | HRESP ERROR, HREADY high, HRDATA zero | PASS |
| Cycles 12-139 | Drive 128 deterministic random transfers | RTL response matches scoreboard model | PASS |

## 7. ahb_default_slave Functional Coverage Summary

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

## 8. ahb_slave_mux Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Check 0 | Drive no slave selected | HRDATA zero, HREADY high, HRESP OKAY, no select error | PASS |
| Checks 1-11 | Select each slave once | Selected slave HRDATA/HREADY/HRESP forwarded | PASS |
| Check 12 | Select UART with HREADY low | HREADY low forwarded | PASS |
| Check 13 | Select default slave with HRESP ERROR | HRESP ERROR forwarded | PASS |
| Checks 14-15 | Drive two-select and all-select illegal cases | HRESP ERROR and select_err asserted | PASS |
| Checks 16-143 | Drive 128 deterministic random one-hot selects | RTL response matches selected slave model | PASS |

## 9. ahb_slave_mux Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 144 |
| No-select path | 1 hit |
| Multi-select error path | 2 hits |
| HREADY low forwarding | 65 hits |
| HRESP ERROR forwarding | 70 hits |
| Slave 0 hits | 13 |
| Slave 1 hits | 13 |
| Slave 2 hits | 11 |
| Slave 3 hits | 14 |
| Slave 4 hits | 9 |
| Slave 5 hits | 17 |
| Slave 6 hits | 13 |
| Slave 7 hits | 13 |
| Slave 8 hits | 12 |
| Slave 9 hits | 9 |
| Slave 10 hits | 17 |
| Scoreboard random check | 128 deterministic random one-hot selects |
