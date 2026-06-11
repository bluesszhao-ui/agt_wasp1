# ahb_default_slave Design Spec

## 1. Scope

`ahb_default_slave` handles unmapped AHB accesses and integration error paths.

The first implementation is zero-wait and combinational, but the module exposes
`hclk_i` and `hresetn_i` to match the interface shape of other AHB-Lite slaves.

## 2. Block Diagram

```text
 hclk_i --------------------+
 hresetn_i -----------------+  reserved for future registered behavior
                             |
 hsel_i -------------------->|\
 htrans_i[1:0] ------------>| | active transfer detect
                             | | active = hsel_i && htrans_i[1]
                             |/
                              |
                              v
                    +------------------+
 hwrite_i --------->| ignored for resp |
 hsize_i[2:0] ----->| policy          |
 hwdata_i[31:0] --->|                 |
                    +--------+---------+
                             |
           +-----------------+-----------------+
           |                                   |
           v                                   v
  hresp_o = ERROR when active          hready_o = 1
  hresp_o = OKAY otherwise            hrdata_o = 0
```

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

## 5. Verification Summary

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
