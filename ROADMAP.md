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
| `timer` | TODO | Machine timer |
| `gpio` | TODO | 32-bit GPIO |
| `uart` | TODO | UART and FIFO |
| `dma` | TODO | Single-channel DMA |
| `intc` | TODO | plic-lite interrupt controller |
| `core` | TODO | RV32I + Zicsr 3-stage core |
| `frontend` | TODO | PC/fetch/redirect |
| `icache` | TODO | Direct-mapped I-cache |
| `dcache` | TODO | Direct-mapped write-through D-cache |
| `tile` | TODO | Core/frontend/cache integration |
| `debug` | TODO | RISC-V External Debug Spec 0.13.x target |
| `wasp1` top | TODO | Full SoC integration |
| `llvm_s1` | TODO | LLVM/BSP/startup/linker/tool scripts |

## Near-Term Plan

```text
1. Move to timer
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
