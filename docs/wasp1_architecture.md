# wasp1 Architecture

## 1. Project Goal

wasp1 is a minimal single-core RV32I SoC inspired by the Rocket Chip module
partitioning style, implemented in synthesizable SystemVerilog.

The design keeps Rocket Chip-like high-level boundaries such as tile, core,
frontend, cache, bus, debug, interrupt, and periphery, while replacing the
Rocket Chip TileLink fabric with an AHB-Lite based SoC interconnect.

## 2. Confirmed Baseline

| Item | Decision |
| --- | --- |
| ISA | RV32I + Zicsr |
| Privilege mode | Machine mode only |
| MMU/TLB/PTW | Not implemented |
| RTL language | SystemVerilog |
| RTL suffix | `.sv` |
| SoC bus | AHB-Lite |
| Internal core/cache interface | Lightweight valid/ready request-response |
| Core microarchitecture | Simple 3-stage pipeline |
| I-cache | Direct-mapped, 16-byte line |
| D-cache | Direct-mapped, 16-byte line, write-through |
| DMA coherence | No hardware cache coherence |
| Debug | RISC-V External Debug Spec 0.13.x compatible target |
| Program storage | Executable OTP |
| OTP programming | CPU-controlled through OTP registers |
| UART programming | Software protocol through boot/program code |
| OTP programming safety | OTP programming routines execute from I-SRAM |
| Implementation targets | IC and Xilinx Virtex-7 FPGA |

## 3. Top-Level Structure

```text
                         +----------------+
                         |     debug      |
                         | JTAG/DTM/DM    |
                         +--------+-------+
                                  |
                                  v
+----------------------------------------------------------------+
|                            wasp1                               |
|                                                                |
|  +--------------------+                                        |
|  |        tile        |                                        |
|  |                    |                                        |
|  | frontend -> icache |----+                                   |
|  | core LSU -> dcache |----+--> core AHB master                |
|  +--------------------+                                        |
|                                                                |
|  +--------------------+                                        |
|  |        dma         |--------> dma AHB master                |
|  +--------------------+                                        |
|                                                                |
|       core master  dma master                                  |
|            |          |                                        |
|            v          v                                        |
|       +----------------------+                                 |
|       |   bus / AHB fabric   |                                 |
|       +----------+-----------+                                 |
|                  |                                             |
|  +---------------+------------------------------------------+  |
|  | OTP I-SRAM D-SRAM DMA WDG timer intc UART I2C GPIO       |  |
|  +----------------------------------------------------------+  |
+----------------------------------------------------------------+
```

## 4. Reset and Execution Model

After reset, the core starts at `OTP_BASE`. OTP is the primary non-volatile
program storage and is executable.

The default software layout is:

| Section | Load location | Run location |
| --- | --- | --- |
| `.text` | OTP | OTP |
| `.rodata` | OTP | OTP |
| `.fasttext` | OTP | I-SRAM |
| `.data` | OTP | D-SRAM |
| `.bss` | None | D-SRAM |
| heap | None | D-SRAM |
| stack | None | D-SRAM |

Startup code may copy `.fasttext` into I-SRAM and `.data` into D-SRAM before
calling `main`.

OTP programming code must run from I-SRAM to avoid modifying the same OTP array
that is currently feeding instruction fetch.

## 5. Cache and DMA Policy

wasp1 does not implement hardware cache coherence.

The first D-cache implementation is write-through. DMA buffers should be placed
in an uncached region or explicitly managed by software. OTP and peripheral
regions are always uncached.

## 6. Debug Model

wasp1 targets OpenOCD/GDB compatibility through a RISC-V External Debug
Spec 0.13.x style debug subsystem.

The debug implementation is staged:

| Stage | Scope |
| --- | --- |
| 1 | JTAG DTM, DMI, dmcontrol, dmstatus, halt/resume, basic GPR access |
| 2 | abstract command, DPC readback, DCSR.step single-step |
| 3 | halted-core Access Memory, native GDB `stepi`, breakpoint planning |

## 7. Design Flow

The project starts with architecture and module documentation. RTL is added
module by module only after the module list and design order are confirmed.

Recommended first implementation target:

```text
common + bus
```

The AHB-Lite fabric is a foundation for all memory-mapped blocks.
