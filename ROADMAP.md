# wasp1 Roadmap

## Status Legend

```text
TODO       Not started
SPEC       Design/verification spec exists
RTL        RTL exists
VERIFY     Testbench exists, verification in progress
PASS       Current verification target passes
```

## Current Progress

| Area | Status | Notes |
| --- | --- | --- |
| Project architecture docs | PASS | Initial architecture and module hierarchy documented |
| `common` foundation | PASS | Verilator lint passes |
| `bus/ahb_decoder` | PASS | Directed, boundary, one-hot, default, and deterministic random tests pass |
| `bus/ahb_default_slave` | PASS | OKAY/ERROR response paths and random tests pass |
| `bus/ahb_slave_mux` | PASS | Response forwarding, no-select, multi-select, random tests pass |
| `bus/ahb_arbiter_2m` | PASS | Round-robin, stall hold, response routing, random tests pass |
| `bus/ahb_fabric_2m` | PASS | Initial fabric integration with mock slaves passes |
| `sram/ahb_sram` | PASS | Byte/half/word, error paths, random write/read tests pass |
| `otp/ahb_otp` | PASS | Executable OTP data window, programming registers, lock/error paths pass |
| `timer/ahb_timer` | PASS | 64-bit mtime/mtimecmp, IRQ mask/pending, error paths pass |
| `gpio/ahb_gpio` | PASS | 32-bit IO, direction, set/clear/toggle, level/edge IRQ paths pass |
| `uart/ahb_uart` | PASS | 8N1 TX/RX loopback, FIFO, IRQ, overrun, error paths pass |
| `dma/ahb_dma` | PASS | Single-channel word copy, registered read-response wait, DMA master, IRQ, error paths pass |
| `intc/ahb_intc` | PASS | PLIC-lite pending, enable, priority, threshold, claim/complete paths pass |
| `core/core_alu` | PASS | RV32I integer ALU ops, edge cases, random reference checks pass |
| `core/core_regfile` | PASS | Reset, x0, dual-read, write, bypass, and random access tests pass |
| `core/core_decode` | PASS | RV32I/Zicsr decode, immediate extraction, and illegal encodings pass |
| `core/core_branch` | PASS | Branch/jump target, compare, priority, and random branch tests pass |
| `core/core_csr` | PASS | Machine CSR ops, masks, counters, IRQ pending, trap, and MRET tests pass |
| `core/core_lsu` | PASS | Load/store request formatting, alignment, extension, and random tests pass |
| `core/core_trap` | PASS | Sync traps, MRET, IRQ masking, and trap priority tests pass |
| `core/core_hazard` | PASS | Load-use stalls, EX/WB forwarding, priority, x0, and random dependency tests pass |
| `core/core_wb` | PASS | Source selection, write suppression, x0, default, and random writeback tests pass |
| `core/core_debug_ctrl` | PASS | Debug halt-pending drain, halted state, resume, step hook, busy block, and priority tests pass |
| `core/core_pipe` | PASS | Pipeline PC, IF/ID, EX/WB, stall, bubble, redirect, fault, and random control tests pass |
| `core/core_int_datapath` | PASS | Executable datapath plus core-side debug halt/DPC/GPR/single-step hooks pass directed coverage |
| `core` | PASS | Top-level wrapper exposes debug_if.core and passes wrapper/integrated simulation |
| `frontend/frontend_pc` | PASS | PC reset, sequential advance, stall/ready hold, redirect priority, misalignment, and random priority tests pass |
| `frontend/frontend_fetch` | PASS | Instruction request encoding, response backpressure, misalignment fault, flush drop, memory error, and random handshakes pass |
| `frontend/frontend_ibuf` | PASS | FIFO ordering, full/empty, simultaneous push/pop, flush, metadata, and random handshakes pass |
| `frontend` | PASS | PC/fetch/ibuf top integration, direct redirect flush, stall, errors, and random latency tests pass |
| `icache/icache_tag` | PASS | Direct-mapped tag/valid lookup, refill update, conflict, invalidate, error, and random tests pass |
| `icache/icache_data` | PASS | Direct-mapped line storage, word select, conflict, write timing, and random tests pass |
| `icache/icache_refill` | PASS | Line-aligned refill FSM, word requests, backpressure, errors, flush, and random tests pass |
| `icache/icache_ctrl` | PASS | Hit/miss control, invalid request faults, refill update, flush, backpressure, and random tests pass |
| `icache` | PASS | Integrated tag/data/control/refill wrapper, miss-to-hit, conflict, error, invalidate, flush, and random tests pass |
| `dcache/dcache_tag` | PASS | Direct-mapped tag/valid lookup, refill update, conflict, invalidate, error, and random tests pass |
| `dcache/dcache_data` | PASS | Direct-mapped line storage, word select, store-hit byte merge, conflict, priority, and random tests pass |
| `dcache/dcache_refill` | PASS | Line-aligned data refill FSM, word requests, backpressure, errors, flush, and random tests pass |
| `dcache/dcache_store` | PASS | Write-through store sequencer, backpressure, errors, flush, and random tests pass |
| `dcache/dcache_ctrl` | PASS | Load/store hit/miss policy, uncached steering, write-through/no-write-allocate, flush, errors, and random tests pass |
| `dcache` | PASS | Integrated tag/data/ctrl/refill/store/uncached wrapper, write-through/no-write-allocate, MMIO/OTP-register uncached bypass, conflict, invalidate, flush, and random tests pass |
| `tile` | PASS | Core/frontend/icache/dcache integration and executable RV32I programs pass |
| `debug/debug_dmi_regs` | PASS | DMI register transport, hart status/control, abstract state, errors, and backpressure pass |
| `debug/debug_halt_ctrl` | PASS | Halt/resume FSM, sticky status, reset priority, aborts, and random core latency pass |
| `debug/debug_reg_access` | PASS | GPR ready/valid sequencing, backpressure, errors, flush drain, and random transactions pass |
| `debug/debug_abstract_cmd` | PASS | RV32 GPR Access Register decode, physical Access Memory, OpenOCD/GDB CSR probes including core-captured DPC, DCSR.step, two execute-address trigger slots, cmderr mapping, aborts, and random commands pass |
| `debug/debug_jtag_dtm` | PASS | JTAG TAP, IDCODE, DTMCS, DMI scan chain, busy/sticky status, and DMI CDC tests pass |
| `debug/debug_jtag` | PASS | Integrated JTAG-to-Debug-Module path passes IDCODE, DTMCS, DMI, halt/resume, GPR abstract access, and sticky reset tests |
| `debug` | PASS | Debug Module top and JTAG-facing wrapper are verified, including DPC readback, DCSR.step single-step, Access Memory, and two OpenOCD/GDB hardware breakpoints |
| `wdg/ahb_wdg` | PASS | Timeout, valid/bad kick, clear priority, IRQ/reset request, AHB error paths, and random timeouts pass |
| `i2c/ahb_i2c` | PASS | TX ACK/NACK, RX ACK/NACK, busy reject, open-drain checks, AHB error paths, and random TX bytes pass |
| `wasp1` top | PASS | Full hierarchy lint, reset-default smoke, SoC JTAG debug smoke, remote-bitbang socket smoke, automated OpenOCD/GDB process register/step/hbreak smoke, OpenOCD/GDB register-write/step/breakpoint stress, long OpenOCD/GDB dual-breakpoint stress, generated OTP firmware boot-to-UART smoke, long multi-peripheral boot smoke, six-round system stress smoke, cache/runtime metrics sweep, mixed IRQ/DMA firmware smoke, DMA real-memory-copy firmware smoke, UART TX/RX/DMA/GPIO external IRQ firmware smokes, timer IRQ firmware smoke, OTP programming-register firmware smoke, debug status, and idle IO stability pass |
| `wasp1` synthesis collateral | PASS | ASIC/DC and Virtex-7/Vivado script skeletons, clock constraints, ASIC SRAM/OTP blackbox filelist, and static collateral checker pass; real library/board synthesis remains |
| Design presentations | PASS | Module/top-level PPT decks exist for common, bus, memories, peripherals, CPU/cache/tile/debug, and wasp1 top |
| Editable OmniGraffle diagrams | PASS | All current design-spec `.graffle` diagrams pass the coordinate/overlap audit |
| `llvm_s1` | PASS | Stage-1 BSP, Homebrew LLVM/lld strict RV32I compile/link smoke, objcopy, OTP image utility, generated UART/long-boot/mixed-IRQ-DMA/system-stress/UART-TX-IRQ/UART-RX-IRQ/GPIO-IRQ/DMA/DMA-IRQ/timer-IRQ/OTP-programming firmware images, local sparse LLVM source checkout, and wasp1 OTP boot/long-boot/mixed-IRQ-DMA/system-stress/DMA/UART-TX-IRQ/UART-RX-IRQ/GPIO-IRQ/DMA-IRQ/timer/programming smokes pass |
| `ftdi_debugger` | SPEC | FT2232H external hardware debugger requirements, reference pinout, OpenOCD FTDI config, Rev A schematic-input/netlist/BOM package, and collateral checker are captured; formal EDA schematic, PCB, and FPGA/board bring-up remain |
| full system software | TODO | Machine timer, UART TX-empty, UART RX/overrun, DMA external interrupt, GPIO external interrupt, long generated-image boot, mixed IRQ/DMA smokes, first six-round polling system stress, first OpenOCD/GDB stress, and long dual-breakpoint OpenOCD/GDB stress pass; randomized software, interrupt-heavy, and optional advanced debug regressions remain |

## Near-Term Plan

```text
1. Bind real ASIC standard-cell/memory libraries or a concrete Virtex-7 board part/pinout and run the first true synthesis reports
2. Develop FT2232H hardware debugger schematic/PCB and validate OpenOCD/GDB on FPGA hardware
3. Extend debug beyond trigger-based hbreak coverage with optional program-buffer, SBA, and data/load/store trigger support
4. Add randomized software and interrupt-heavy stress regressions
```

## Commit Policy Going Forward

Use one verified module milestone per commit where practical.

Each implementation commit should include:

```text
spec updates
RTL
testbench
Makefile/filelist changes
verification report
passing lint/sim result
```
