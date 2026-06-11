# sram Verification Plan

## 1. Goals

Verify `ahb_sram` as a reusable AHB-Lite memory slave.

The first milestone focuses on single-transfer AHB behavior, byte lane writes,
alignment/range error handling, and deterministic random word accesses.

## 2. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Cycles 0-3 | Apply reset | HREADY high, HRESP OKAY, HRDATA zero | PASS |
| Directed | Word write/read | Full 32-bit word is preserved | PASS |
| Directed | Halfword write to upper lane | Only selected halfword updates | PASS |
| Directed | Byte writes to lanes 0/1/2/3 | Only selected byte lane updates | PASS |
| Directed | Unselected NONSEQ write attempt | Memory remains unchanged | PASS |
| Directed | Misaligned halfword and word transfers | HRESP ERROR | PASS |
| Directed | Out-of-range and below-base transfers | HRESP ERROR | PASS |
| Random | 16 deterministic word write/read pairs | Read data matches written data | PASS |

## 3. Coverage Intent

```text
word transfer path
halfword transfer path
byte transfer path
all byte lanes
read response path
write response path
idle/unselected path
misalignment errors
range errors
deterministic random accesses
```
