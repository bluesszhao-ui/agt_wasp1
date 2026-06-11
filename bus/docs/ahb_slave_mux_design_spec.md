# ahb_slave_mux Design Spec

## 1. Scope

`ahb_slave_mux` forwards the response from the selected AHB slave back toward the
granted master.

It is a pure combinational block.

## 2. Block Diagram

```text
 hsel_i[10:0] ---------------------------+
                                         |
 slave_hrdata_i[0]  slave_hready_i[0]  slave_hresp_i[0]
 slave_hrdata_i[1]  slave_hready_i[1]  slave_hresp_i[1]
        ...              ...                 ...
 slave_hrdata_i[10] slave_hready_i[10] slave_hresp_i[10]
        |                |                   |
        +----------------+-------------------+
                         |
                         v
             +----------------------+
             |  one-hot checker     |
             |                      |
             | no select: OKAY      |
             | one select: forward  |
             | multi select: ERROR  |
             +----------+-----------+
                        |
        +---------------+----------------+
        |               |                |
        v               v                v
   hrdata_o        hready_o          hresp_o
                        |
                        v
                  select_err_o
```

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
