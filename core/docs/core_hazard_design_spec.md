# core_hazard Design Spec

## 1. Scope

`core_hazard` is a combinational helper for the planned simple in-order core
pipeline.

## 2. Editable Block Diagram

```text
editable source: core/docs/diagrams/core_hazard_block.graffle
preview export:  none
detail level:    L1
clock domains:   none; pure combinational logic
```

The diagram separates decode source inputs, execute/writeback destination
inputs, register-match comparison, forwarding selection, load-use stall
generation, and hazard-control outputs. No pipeline state is stored in this
module.

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
