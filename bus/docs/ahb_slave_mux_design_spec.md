# ahb_slave_mux Design Spec

## 1. Scope

`ahb_slave_mux` forwards the response from the selected AHB slave back toward the
granted master.

It is a pure combinational block.

## 2. Editable Block Diagram

```text
editable source: bus/docs/diagrams/ahb_slave_mux_block.graffle
preview export:  none
detail level:    L1
clock domains:   none; pure combinational logic
```

The diagram separates select/response array inputs, one-hot checking, selected
response muxing, and fabric response outputs.

## 3. Ports

| Port | Direction | Description |
| --- | --- | --- |
| `hsel_i` | input | One-hot slave select vector |
| `slave_hrdata_i` | input | Read data from each slave |
| `slave_hready_i` | input | Ready from each slave |
| `slave_hresp_i` | input | Response from each slave |
| `hrdata_o` | output | Selected read data |
| `hready_o` | output | Selected ready |
| `hresp_o` | output | Selected response |
| `select_err_o` | output | Asserted when multiple slaves are selected |

## 4. Behavior

```text
no selected slave:
  HRDATA = 0
  HREADY = 1
  HRESP  = OKAY
  select_err_o = 0

exactly one selected slave:
  HRDATA/HREADY/HRESP = selected slave response
  select_err_o = 0

multiple selected slaves:
  HRDATA = 0
  HREADY = 1
  HRESP  = ERROR
  select_err_o = 1
```

## 5. Verification Summary

Verified by `tb_ahb_slave_mux`.

Coverage includes:

```text
no-select path
every slave selected
HREADY low forwarding
HRESP ERROR forwarding
multi-select error detection
128 deterministic random one-hot selects
```
