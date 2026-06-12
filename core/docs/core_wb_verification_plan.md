# core_wb Verification Plan

## 1. Strategy

Use a self-checking SystemVerilog testbench with a local reference model.

## 2. Directed Cases

| Case | Intent |
| --- | --- |
| ALU source | Select ALU result |
| Load source | Select formatted load data |
| CSR source | Select CSR read data |
| PC+4 source | Select jump link value |
| Immediate source | Select LUI immediate value |
| Invalid slot | Suppress write enable |
| No rd write | Suppress write enable |
| Trap | Suppress write enable |
| Fault | Suppress write enable |
| x0 | Suppress writes to x0 |
| Default selector | Unknown selector falls back to ALU result |

## 3. Random Cases

Run 200 deterministic random cases over valid, rd, write intent, selector,
trap, fault, and candidate source values.

## 4. Exit Criteria

All directed cases and random cases must match the reference model. Coverage
counters must show all planned source and suppression classes were exercised.
