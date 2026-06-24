# wasp1 Design Plan

## 1. Design Method

Design proceeds one module at a time. Each module receives:

1. Design spec
2. Interface definition
3. RTL implementation
4. Testbench
5. Filelist
6. Makefile target
7. Verification case table
8. Simulation logs and waveform output

No top-level SoC RTL is created until the lower-level modules needed for
integration are implemented and verified.

## 2. Recommended Order

| Step | Module | Reason |
| ---: | --- | --- |
| 1 | common | Shared packages, interfaces, synchronizers, FIFOs |
| 2 | bus | Foundation for all memory-mapped blocks |
| 3 | sram | Provides real AHB read/write targets |
| 4 | otp | Defines reset/program storage model |
| 5 | timer | Simple register block and interrupt source |
| 6 | gpio | Simple peripheral with input/output/interrupt |
| 7 | uart | Required for software-visible bring-up and OTP programming flow |
| 8 | dma | Adds the second AHB master and arbitration pressure |
| 9 | intc | Aggregates external interrupts |
| 10 | core | Minimal RV32I + Zicsr execution path |
| 11 | frontend | PC and fetch control |
| 12 | icache | Instruction cache and refill path |
| 13 | dcache | Data cache and write-through path |
| 14 | tile | Core/frontend/cache integration |
| 15 | debug | RISC-V debug flow for OpenOCD/GDB |
| 16 | wasp1 | Full SoC integration |
| 17 | llvm_s1 | BSP, linker, startup, boot/program software |
| 18 | full system | End-to-end SoC simulation |

## 3. First RTL Milestone

The first RTL milestone is:

```text
common + bus
```

This includes AHB-Lite interfaces, address decode, 2-master arbitration, slave
muxing, and default error response.

## 4. Documentation Rule

Each module gets a design spec under `module/docs/`. Block diagrams must not use
Mermaid. Preferred diagram formats are:

```text
ASCII block diagram
editable OmniGraffle .graffle source for detailed engineering figures
optional PNG/PDF preview export for Markdown viewing
```

New or substantially reworked OmniGraffle diagrams must follow
`docs/wasp1_omnigraffle_diagram_policy.md`.

Each verification plan must include a time-sequenced case table describing the
actions and expected results during each test interval.
