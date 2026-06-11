# bus Design Spec

## 1. Scope

`bus` implements the wasp1 AHB-Lite interconnect.

The SoC has two AHB masters:

```text
core
dma
```

The SoC has these AHB slaves:

```text
OTP
I-SRAM
D-SRAM
DMA regs
WDG
timer
intc
UART
I2C
GPIO
default error slave
```

## 2. Block Diagram

```text
                         +-------------------+
 core AHB master ------->|                   |
                         | ahb_arbiter_2m    |
 dma AHB master -------->| round-robin grant |
                         |                   |
                         +---------+---------+
                                   |
                                   | selected AHB address/control/write data
                                   v
                         +-------------------+
                         | ahb_decoder       |
                         | address -> HSEL   |
                         +---------+---------+
                                   |
            +----------------------+----------------------+
            |                                             |
            v                                             v
  +-------------------+                         +-------------------+
  | selected slave    |                         | ahb_default_slave |
  | OTP/SRAM/periph   |                         | unmapped error    |
  +---------+---------+                         +---------+---------+
            |                                             |
            +----------------------+----------------------+
                                   |
                                   | HRDATA/HRESP/HREADY
                                   v
                         +-------------------+
                         | ahb_slave_mux     |
                         | return selected   |
                         +---------+---------+
                                   |
                                   v
                         granted master response
```

## 3. Submodules

| Module | Purpose |
| --- | --- |
| `ahb_arbiter_2m` | Select core or DMA master |
| `ahb_decoder` | Decode address and generate one-hot slave select |
| `ahb_slave_mux` | Mux selected slave response |
| `ahb_default_slave` | Error response for unmapped addresses |
| `ahb_reg_slice` | Optional timing register slice |
| `ahb_to_reg_if` | Helper bridge for simple register blocks |
| `ahb_fabric_2m` | Integrated 2-master fabric with decoder, default slave, and response mux |

## 4. Arbitration

Initial policy is two-master round-robin.

When both masters request at the same time, the grant alternates after accepted
transfers. This avoids starving either core or DMA.

Locked transfers are reserved in the interface but are not used by the first
wasp1 implementation.

`ahb_arbiter_2m` uses registered grant state.

Behavior:

```text
reset:
  no active grant
  first simultaneous request after reset grants core/m0

one requester:
  grant the requesting master

two requesters:
  grant the master that did not win the previous accepted grant

downstream HREADY low:
  hold grant and selected address/control/data stable

non-granted requesting master:
  HREADY returned low

idle non-granted master:
  HREADY returned high
```

The arbiter forwards downstream `HRDATA/HRESP/HREADY` only to the granted
master. The non-granted master sees zero read data and OKAY response.

## 5. Address Decode

The initial decode follows `docs/wasp1_memory_map.md`.

| Index | Slave | Base | Initial size |
| ---: | --- | ---: | ---: |
| 0 | OTP | `0x0000_0000` | `0x0001_0000` |
| 1 | I-SRAM | `0x1000_0000` | `0x0001_0000` |
| 2 | D-SRAM | `0x2000_0000` | `0x0001_0000` |
| 3 | DMA regs | `0x4000_0000` | `0x0000_1000` |
| 4 | WDG | `0x4001_0000` | `0x0000_1000` |
| 5 | timer | `0x4002_0000` | `0x0000_1000` |
| 6 | intc | `0x4003_0000` | `0x0000_1000` |
| 7 | UART | `0x4004_0000` | `0x0000_1000` |
| 8 | I2C | `0x4005_0000` | `0x0000_1000` |
| 9 | GPIO | `0x4006_0000` | `0x0000_1000` |
| 10 | default | unmatched | N/A |

Unmatched addresses select `ahb_default_slave`.

The memory sizes above are initial RTL parameters in `wasp1_pkg`. They can be
changed later without changing the decoder interface.

## 6. ahb_decoder

`ahb_decoder` is combinational.

Inputs:

```text
haddr_i
active_i
```

Outputs:

```text
hsel_o[AHB_SLAVE_COUNT-1:0]
default_sel_o
```

When `active_i` is low, no slave is selected. When `active_i` is high, exactly
one bit of `hsel_o` is asserted. Unmapped addresses select
`AHB_SLAVE_DEFAULT`.

## 7. ahb_default_slave

`ahb_default_slave` handles unmapped or otherwise invalid decoded accesses.

Inputs:

```text
hclk_i
hresetn_i
hsel_i
htrans_i
hwrite_i
hsize_i
hwdata_i
```

Outputs:

```text
hrdata_o
hready_o
hresp_o
```

Behavior:

```text
hready_o = 1
hrdata_o = 0
hresp_o  = ERROR when hsel_i=1 and htrans_i is NONSEQ or SEQ
hresp_o  = OKAY otherwise
```

The default slave does not stall. It ignores write data and transfer size, but
the verification still covers read/write and byte/halfword/word combinations to
make sure they do not affect the response policy.

`hclk_i` and `hresetn_i` are present to keep the module interface aligned with
other AHB-Lite slaves. The first implementation is zero-wait and combinational;
the clock/reset ports are reserved for future response-phase or assertion logic.

## 8. ahb_slave_mux

`ahb_slave_mux` selects the response from the active slave.

Inputs:

```text
hsel_i[AHB_SLAVE_COUNT-1:0]
slave_hrdata_i[AHB_SLAVE_COUNT]
slave_hready_i[AHB_SLAVE_COUNT]
slave_hresp_i[AHB_SLAVE_COUNT]
```

Outputs:

```text
hrdata_o
hready_o
hresp_o
select_err_o
```

Behavior:

```text
no selected slave:
  HRDATA = 0
  HREADY = 1
  HRESP  = OKAY
  select_err_o = 0

exactly one selected slave:
  HRDATA/HREADY/HRESP are forwarded from the selected slave
  select_err_o = 0

multiple selected slaves:
  HRDATA = 0
  HREADY = 1
  HRESP  = ERROR
  select_err_o = 1
```

The normal fabric path expects `ahb_decoder` to produce one-hot selects.
`select_err_o` exists to expose integration bugs during verification.

## 9. AHB-Lite Subset

## 9. ahb_fabric_2m

`ahb_fabric_2m` integrates:

```text
ahb_arbiter_2m
ahb_decoder
ahb_default_slave
ahb_slave_mux
```

It exposes two master-side ports and ten external slave-side ports. The default
slave is internal to the fabric. Unmapped addresses assert `default_sel_o` and
return an ERROR response without selecting any external slave.

See `bus/docs/ahb_fabric_2m_design_spec.md` for the detailed fabric block
diagram.

## 10. AHB-Lite Subset

The first bus implementation supports:

```text
single transfers
IDLE and NONSEQ transfer types
byte/halfword/word HSIZE
HREADY-based stalling
OKAY and ERROR responses
```

Burst transfers are not required for the first implementation.
