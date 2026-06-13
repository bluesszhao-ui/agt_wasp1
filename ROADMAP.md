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
| `dma/ahb_dma` | PASS | Single-channel word copy, DMA master, IRQ, error paths pass |
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
| `core/core_pipe` | PASS | Pipeline PC, IF/ID, EX/WB, stall, bubble, redirect, fault, and random control tests pass |
| `core/core_int_datapath` | PASS | Executable integer/load-store datapath for ALU, LUI/AUIPC, branch/JAL/JALR redirect, loads, stores, LSU faults, and suppression paths passes |
| `core` | TODO | Remaining RV32I + Zicsr 3-stage core integration |
| `frontend` | TODO | PC/fetch/redirect |
| `icache` | TODO | Direct-mapped I-cache |
| `dcache` | TODO | Direct-mapped write-through D-cache |
| `tile` | TODO | Core/frontend/cache integration |
| `debug` | TODO | RISC-V External Debug Spec 0.13.x target |
| `wasp1` top | TODO | Full SoC integration |
| `llvm_s1` | TODO | LLVM/BSP/startup/linker/tool scripts |

## Near-Term Plan

```text
1. Integrate CSR/trap/interrupt behavior into the executable core datapath
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
