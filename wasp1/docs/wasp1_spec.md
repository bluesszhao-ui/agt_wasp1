# wasp1 Spec

## 1. Purpose

`wasp1` is the single-core SoC integration top. It connects the RV32I+Zicsr
tile, I-cache, D-cache, AHB-Lite fabric, DMA, executable OTP, I-SRAM, D-SRAM,
watchdog, timer, interrupt controller, UART, I2C, and GPIO.

## 2. Bus Topology Requirements

The SoC fabric must expose two AHB-Lite masters:

| Master | Source | Requirement |
| --- | --- | --- |
| M0 | Core-side memory bridge | Carries tile I-cache and D-cache downstream accesses. |
| M1 | DMA | Carries DMA read/write transfers. |

The decoded external slave windows are:

| Slave index | Window |
| --- | --- |
| `AHB_SLAVE_OTP` | Executable OTP |
| `AHB_SLAVE_ISRAM` | I-SRAM |
| `AHB_SLAVE_DSRAM` | D-SRAM |
| `AHB_SLAVE_DMA` | DMA control registers |
| `AHB_SLAVE_WDG` | Watchdog |
| `AHB_SLAVE_TIMER` | Machine timer |
| `AHB_SLAVE_INTC` | Interrupt controller |
| `AHB_SLAVE_UART` | UART |
| `AHB_SLAVE_I2C` | I2C master |
| `AHB_SLAVE_GPIO` | GPIO |

## 3. Reset and Boot Requirements

All integrated sequential logic uses `hclk_i` and active-low `hresetn_i`.
The tile boot PC must be `OTP_BASE`, making OTP the executable program storage
after reset.

## 4. Interrupt Requirements

The timer interrupt connects directly to the tile machine timer interrupt
input. External interrupt sources are collected through `ahb_intc`:

| INTC source ID | Source |
| --- | --- |
| 1 | Watchdog |
| 2 | UART |
| 3 | I2C |
| 4 | GPIO |
| 5 | DMA |

The interrupt controller `meip_o` output connects to the tile machine external
interrupt input.

## 5. IO Requirements

`wasp1` must expose UART RX/TX, I2C open-drain drive signals, GPIO input/output
signals, watchdog reset request, trap observation, bus grant observation, and
the JTAG pins for the integrated Debug Module.

## 6. Debug Boundary

The current top instantiates `debug_jtag`, which connects JTAG TAP/DTM scans to
the RISC-V Debug Module and then to the tile `debug_if` channel.

| Signal | Requirement |
| --- | --- |
| `jtag_tck_i` | External JTAG test clock for TAP/scan state. |
| `jtag_trst_ni` | Active-low JTAG TAP reset. |
| `jtag_tms_i` | JTAG test mode select. |
| `jtag_tdi_i` | JTAG serial data input. |
| `jtag_tdo_o` | JTAG serial data output. |
| `dbg_halted_o`, `dbg_running_o` | Observable core debug status. |
| `dbg_dmactive_o` | Observable Debug Module active state. |
| `dbg_ndmreset_o` | Debug Module non-debug reset request. |
| `dbg_dtm_hardreset_o` | DTMCS hard-reset pulse observation. |

OpenOCD/GDB process-level validation is part of the top-level smoke
verification and uses the remote-bitbang JTAG path. The current debug path
supports native GDB `stepi`, two execute-address hardware breakpoints, and
exact-address load/store watchpoints through the Debug Spec trigger CSR path.

## 7. Verification Requirements

Verification must cover SoC elaboration, reset defaults, core-side fetch
activity through the OTP/fabric path, JTAG Debug Module smoke access,
OpenOCD/GDB connect/register/step/hardware-breakpoint/load-store-watchpoint
smoke, benign idle IO behavior, and target macro lint for IC and Xilinx
Virtex-7 FPGA builds.
