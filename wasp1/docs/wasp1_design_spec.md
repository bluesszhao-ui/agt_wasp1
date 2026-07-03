# wasp1 Design Spec

## 1. Scope

`wasp1` is the structural SoC top. It owns no architectural CPU state. Its main
local sequential behavior is in `wasp1_core_ahb_bridge`, which merges the
tile's I-cache and D-cache downstream memory ports into the single core-side
AHB master required by the SoC bus contract.

## 2. Editable Diagram

```text
editable source: wasp1/docs/diagrams/wasp1_block.graffle
preview export:  none
detail level:    L3
clock domain:    SEQ clk=hclk_i rst=hresetn_i
```

The diagram separates bridge arbitration decode, bridge transaction registers,
fabric decode/muxing, and peripheral sequential blocks.

## 3. Top-Level Blocks

| Block | Timing class | Function |
| --- | --- | --- |
| External IO/debug pins | `IF` | UART, I2C, GPIO, JTAG, watchdog reset, trap/bus/debug observations. |
| Tile | `SEQ hclk_i/hresetn_i` | Frontend, core, I-cache, and D-cache integration. |
| Debug JTAG wrapper | `SEQ hclk_i/hresetn_i` + `SEQ jtag_tck_i/jtag_trst_ni` | JTAG TAP/DTM, DMI transport, Debug Module registers, and tile debug control. |
| Core I/D arbitration | `COMB` | Selects D-cache request over I-cache request while bridge is idle. |
| Core AHB bridge state | `SEQ hclk_i/hresetn_i` | Holds selected request, AHB phase state, and cache response. |
| AHB fabric arbiter/default | `SEQ hclk_i/hresetn_i` | Arbitrates core/DMA, holds response-route master, and registers default-slave response. |
| AHB decoder/mux | `COMB` + `SEQ hclk_i/hresetn_i` | Decodes address-phase slave select, registers data-phase select, and multiplexes slave responses. |
| DMA | `SEQ hclk_i/hresetn_i` | AHB slave control register block plus AHB master transfer engine. |
| OTP/I-SRAM/D-SRAM | `SEQ hclk_i/hresetn_i` | Executable OTP and scratch SRAM targets. |
| Peripherals | `SEQ hclk_i/hresetn_i` | WDG, timer, INTC, UART, I2C, and GPIO register/state blocks. |
| IRQ vector pack | `COMB` | Packs WDG/UART/I2C/GPIO/DMA interrupts into INTC source bits. |

## 4. Core AHB Bridge FSM

`wasp1_core_ahb_bridge` uses five states:

| State | Meaning | Transition |
| --- | --- | --- |
| `BR_IDLE` | No outstanding request | D-cache valid -> `BR_ADDR`; else I-cache valid -> `BR_ADDR`. |
| `BR_ADDR` | AHB address phase is driven | `hready_i=1` -> `BR_DATA_WAIT`; otherwise hold. |
| `BR_DATA_WAIT` | Registered SoC slave/fabric response path advances one cycle | `hready_i=1` -> `BR_RESP`; otherwise hold. |
| `BR_RESP` | AHB response phase is sampled | `hready_i=1` -> latch `hrdata_i/hresp_i`, then `BR_RSP_HOLD`. |
| `BR_RSP_HOLD` | Selected cache response is held | Selected cache `rsp_ready=1` -> `BR_IDLE`. |

D-cache wins when both cache ports request while the bridge is idle. The bridge
allows only one outstanding transfer, which matches the simple single-beat
AHB-Lite transfers used by current caches and SRAM/peripheral targets.
`BR_DATA_WAIT` matches the project slave contract: SRAM, OTP, and peripherals
capture the address phase first and drive their registered read data/response on
the following clock.

## 5. Address and Interrupt Integration

The AHB fabric uses the common `wasp1_pkg` base addresses and slave indices.
The timer bypasses INTC as machine timer interrupt. WDG, UART, I2C, GPIO, and
DMA feed INTC as external interrupt sources, with source zero reserved.

## 6. Debug Integration Boundary

`wasp1` internally instantiates `debug_if` between the tile and `debug_jtag`.
The external debug boundary is now JTAG:

```text
JTAG pins -> debug_jtag -> debug_jtag_dtm -> debug_dmi_if -> debug -> debug_if -> tile
```

The wrapper uses two clock domains. TAP/scan state is clocked by `jtag_tck_i`
and reset by `jtag_trst_ni`/`hresetn_i`. DMI ready/valid, Debug Module
registers, halt/resume control, and core GPR debug access use
`hclk_i/hresetn_i`.

The SoC generates a one-cycle `hart_reset_event` after `hresetn_i` releases so
`dmstatus.havereset` can report that hart reset occurred after Debug Module
reset.

## 7. Target Support

The top does not introduce target-specific behavior. Child memory wrappers and
target attributes remain selected by:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
