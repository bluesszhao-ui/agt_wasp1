# tile Spec

## 1. Scope

`tile` is the first CPU-tile integration boundary for wasp1.

The tile groups the machine-mode RV32I+Zicsr core, frontend, instruction cache,
and later data cache blocks. It presents downstream lightweight valid/ready
memory initiator ports that later SoC integration will adapt to AHB-Lite:

```text
instruction memory port -> later SoC/AHB instruction path
data memory port        -> later SoC/AHB data path
```

The tile is not the whole SoC. It does not instantiate AHB-Lite fabric, SRAM,
OTP, DMA, debug module, interrupt controller, or peripherals.

## 2. Integration Decision

The architectural decision for wasp1 is:

```text
frontend owns boot PC, sequential fetch PC, request issue, and redirect reload
core consumes an instruction valid/ready stream with PC/fault metadata
core emits branch/trap/MRET redirect valid + target PC back to frontend
icache services frontend fetch requests
```

This avoids two independent fetch PC owners in the tile and matches the
Rocket-like separation where frontend owns instruction fetch while the core
pipeline owns decode/execute/commit and redirect decisions.

The data side is intentionally not connected to `dcache` until the current core
LSU/data-memory boundary is upgraded. The implemented core data path currently
has a staged request plus combinational response style, while `dcache` is a
multi-cycle valid/ready request-response block. The tile must not hide that
interface mismatch with a lossy adapter.

## 3. External Interface Contract

The first fetch-integrated `tile` RTL should expose:

| Signal/interface | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | Tile clock for core, frontend, and cache children. |
| `rst_ni` | input | Active-low asynchronous tile reset. |
| `boot_pc_i` | input | Frontend reset fetch PC, normally `OTP_BASE`. |
| `timer_irq_i` | input | Machine timer interrupt pending input to core. |
| `external_irq_i` | input | Machine external interrupt pending input to core. |
| `icache_flush_i` | input | Flush active I-cache controller/refill work. |
| `icache_invalidate_i` | input | Invalidate I-cache tag valid bits. |
| `imem_if` | initiator | Downstream instruction memory request/response port from I-cache. |

For verification and future debug/trace integration, tile should also expose
the core observation outputs already provided by `core`:

```text
commit_*
ex_*
illegal_o
lsu_fault_o
trap_*
mret_taken_o
redirect_*
csr_rdata_o
hazard_*
unsupported_o
```

The later data-cache-integrated tile adds:

| Signal/interface | Direction | Description |
| --- | --- | --- |
| `dcache_flush_i` | input | Flush active D-cache controller/refill/store work. |
| `dcache_invalidate_i` | input | Invalidate D-cache tag valid bits. |
| `dmem_if` | initiator | Downstream data memory request/response port from D-cache. |

## 4. Fetch Protocol Mapping

The tile instruction path maps `frontend` to `icache` and `core`:

```text
frontend.imem_if.req_*  -> icache.front_if.req_*
icache.front_if.rsp_*   -> frontend.imem_if.rsp_*
frontend.instr_valid_o  -> core.instr_valid_i
frontend.instr_ready_i  <- core.instr_ready_o
frontend.instr_pc_o     -> core.instr_pc_i
frontend.instr_o        -> core.instr_i
frontend.instr_fault_o  -> core.instr_fault_i
core.redirect_valid_o   -> frontend.redirect_valid_i
core.redirect_pc_o      -> frontend.redirect_pc_i
```

`frontend` drives word-aligned instruction fetch requests. `icache` translates
misses to the downstream `imem_if` initiator. `core` never drives an instruction
memory request directly.

## 5. Data Protocol Precondition

Before `dcache` is instantiated in `tile`, one of these design changes is
required and must be specified, implemented, and verified:

```text
preferred:
  add valid/ready request and valid/ready response handshake to core LSU/data
  memory boundary, including pipeline stall until load response arrives

acceptable if documented:
  insert a tile-owned sequential request/response adapter that can never drop,
  duplicate, or reorder the staged core request stream
```

The preferred path is the core LSU handshake upgrade because it makes stalls
architecturally visible inside the pipeline and keeps tile from owning hidden
execution state.

## 6. Reset, Flush, And Invalidate

`rst_ni` resets frontend, core, and cache controller/refill sequential state.

I-cache flush inputs abort active cache work but do not clear all tag valid
bits. I-cache invalidate inputs clear tag valid bits according to the I-cache
module spec.

The tile itself must not alter the programmer-visible cache policy:

```text
I-cache: direct-mapped, load-miss refill
D-cache later: direct-mapped, load-miss allocate, store write-through,
               store miss no-write-allocate
```

## 7. Target Support

`tile` must remain target-neutral synthesizable SystemVerilog. Any IC or
Virtex-7 FPGA target selection must stay inside child cache/memory wrappers or
documented target-specific primitive wrappers.

The tile must not change programmer-visible behavior under:

```text
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
WASP1_TARGET_SIM_GENERIC
```

## 8. Out Of Scope For The Fetch-Integrated Milestone

The first fetch-integrated tile milestone does not include:

```text
AHB-Lite conversion
I/D downstream arbitration
D-cache connection before core LSU handshake support
debug module integration
cache maintenance CSRs
clock gating
multi-clock crossing
```
