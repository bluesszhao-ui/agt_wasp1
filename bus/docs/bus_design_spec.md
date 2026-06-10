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

| Slave | Base |
| --- | ---: |
| OTP | `0x0000_0000` |
| I-SRAM | `0x1000_0000` |
| D-SRAM | `0x2000_0000` |
| DMA regs | `0x4000_0000` |
| WDG | `0x4001_0000` |
| timer | `0x4002_0000` |
| intc | `0x4003_0000` |
| UART | `0x4004_0000` |
| I2C | `0x4005_0000` |
| GPIO | `0x4006_0000` |

Unmatched addresses select `ahb_default_slave`.

## 6. AHB-Lite Subset

The first bus implementation supports:

```text
single transfers
IDLE and NONSEQ transfer types
byte/halfword/word HSIZE
HREADY-based stalling
OKAY and ERROR responses
```

Burst transfers are not required for the first implementation.
