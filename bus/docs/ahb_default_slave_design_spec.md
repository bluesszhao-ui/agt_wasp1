# ahb_default_slave Design Spec

## 1. Scope

`ahb_default_slave` handles unmapped AHB accesses and integration error paths.

The first implementation is zero-wait and combinational, but the module exposes
`hclk_i` and `hresetn_i` to match the interface shape of other AHB-Lite slaves.

## 2. Editable Block Diagram

```text
editable source: bus/docs/diagrams/ahb_default_slave_block.graffle
preview export:  none
detail level:    L1
clock domains:   none in current response logic; hclk_i/hresetn_i are IF-only
```

The diagram separates AHB inputs, active-transfer detection, combinational
response policy, and response outputs. No sequential response state exists in
this revision.

## 3. Ports

| Port | Direction | Description |
| --- | --- | --- |
| `hclk_i` | input | AHB clock, reserved in current implementation |
| `hresetn_i` | input | Active-low reset, reserved in current implementation |
| `hsel_i` | input | Default slave select |
| `htrans_i` | input | AHB transfer type |
| `hwrite_i` | input | Write indicator, ignored for response policy |
| `hsize_i` | input | Transfer size, ignored for response policy |
| `hwdata_i` | input | Write data, ignored for response policy |
| `hrdata_o` | output | Always zero |
| `hready_o` | output | Always one |
| `hresp_o` | output | OKAY or ERROR response |

## 4. Behavior

```text
selected NONSEQ/SEQ transfer -> HRESP ERROR
unselected transfer          -> HRESP OKAY
selected IDLE/BUSY transfer  -> HRESP OKAY
HREADY                       -> 1
HRDATA                       -> 0
```

## 5. Sequential State

The current implementation has no sequential state. `hclk_i` and `hresetn_i`
are reserved interface pins only, so no FSM, register-transfer diagram, or reset
state exists for this revision.

If a future implementation registers the default response, this section must be
updated with the response-state diagram and reset values.

## 6. Verification Summary

Verified by `tb_ahb_default_slave`.

Coverage includes:

```text
unselected transfers
selected IDLE/BUSY transfers
selected NONSEQ/SEQ transfers
read and write controls
byte/halfword/word sizes
HREADY always high
HRDATA always zero
128 deterministic random transfers
```
