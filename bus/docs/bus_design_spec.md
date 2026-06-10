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

## 4. Arbitration

Initial policy is two-master round-robin.

When both masters request at the same time, the grant alternates after accepted
transfers. This avoids starving either core or DMA.

Locked transfers are reserved in the interface but are not used by the first
wasp1 implementation.

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

## 7. AHB-Lite Subset

The first bus implementation supports:

```text
single transfers
IDLE and NONSEQ transfer types
byte/halfword/word HSIZE
HREADY-based stalling
OKAY and ERROR responses
```

Burst transfers are not required for the first implementation.
