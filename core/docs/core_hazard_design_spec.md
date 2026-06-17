# core_hazard Design Spec

## 1. Scope

`core_hazard` is a combinational helper for the planned simple in-order core
pipeline.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic
All logic blocks in this diagram are COMB. No DUT clock/reset is used.

 id rs1/rs2 use ----+
                    v
 ex rd/write/load --> COMB dependency compare ---> load-use stall controls
                    |
 wb rd/write -------+----> EX/WB forwarding selects
```

## 3. Design

The module computes nonzero register matches between decode sources and
execute/writeback destinations.

EX forwarding is selected when:

```text
decode source matches execute rd
execute writes rd
execute is not a load
```

WB forwarding is selected when:

```text
decode source matches writeback rd
writeback writes rd
EX forwarding for that source is not selected
```

Load-use stall is selected when decode uses a source register that matches an
execute-stage load destination. The stall is exposed as fetch/decode hold plus
execute bubble controls.

## 4. Target Support

The module is target-neutral combinational logic. No IC or FPGA-specific
primitive is required.
