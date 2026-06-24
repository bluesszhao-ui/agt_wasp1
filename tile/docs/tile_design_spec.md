# tile Design Spec

## 1. Scope

`tile` integrates the already implemented `frontend`, `core`, `icache`, and
`dcache` modules into one CPU tile with independent instruction and data
downstream memory ports.

## 2. Planned Block Diagram

![tile timing and state ownership](images/tile_state.png)

This is a historical PNG timing-class view. New or substantially reworked tile
figures should use editable OmniGraffle source under `tile/docs/diagrams/`. The
text diagram below retains signal-level detail for reviews and plain-text
tooling.

```text
Legend:
  SEQ  = sequential state, pale green in generated diagrams/PPT
  COMB = combinational logic, pale amber/yellow
  IF   = external/interface boundary, pale blue

Clock/reset domain:
  all SEQ blocks below use clk=clk_i, rst=rst_ni

 IF clk_i/rst_ni/boot_pc/irq/cache control/debug
        |
        v
+------------------------------------------------------------------------+
| tile                                                                   |
|                                                                        |
|  +-----------------------------+                                       |
|  | SEQ clk_i/rst_ni            |                                       |
|  | frontend                    |<-----------+                          |
|  | PC/redirect/ibuf state      |            |                          |
|  +------+----------------------+            |                          |
|         | frontend imem_if                  | core redirect            |
|         v                                   | valid/pc                 |
|  +-----------------------------+            |                          |
|  | IF icache front_if.target   |            |                          |
|  +-------------+---------------+            |                          |
|                |                            |                          |
|                v                            |                          |
|  +-----------------------------+            |                          |
|  | SEQ clk_i/rst_ni            |            |                          |
|  | icache tag/data/refill/ctrl |            |                          |
|  +-------------+---------------+            |                          |
|                |                            |                          |
|                v                            |                          |
|  IF imem_if downstream initiator            |                          |
|                                             |                          |
|  +-----------------------------+            |                          |
|  | SEQ clk_i/rst_ni            |------------+                          |
|  | core pipe/rf/csr/trap/lsu   |                                       |
|  +-------------+---------------+                                       |
|                ^                                                       |
|                | frontend instr_valid/ready/pc/instr/fault             |
|                +-------------------------------------------------------+
|                                                                        |
|  | COMB core/D-cache request-response wiring |                         |
|  +----------------------+--------------------+                         |
|                         v                                              |
|  +-----------------------------+                                       |
|  | SEQ clk_i/rst_ni            |                                       |
|  | dcache tag/data/refill/ctrl |                                       |
|  +-------------+---------------+                                       |
|                |                                                       |
|                v                                                       |
|  IF dmem_if downstream initiator                                       |
|  IF commit/trap/hazard/debug-observe outputs                           |
|  IF debug_if.core pass-through to core                                  |
+------------------------------------------------------------------------+
```

## 3. Child Instances

| Instance | Module | Purpose |
| --- | --- | --- |
| `u_frontend` | `frontend` | Owns boot PC, sequential fetch PC, redirect reload, request issue, and instruction buffering. |
| `u_icache` | `icache` | Instruction fetch cache behind the frontend request stream. |
| `u_core` | `core` | RV32I+Zicsr machine-mode execution and observation outputs. |
| `u_dcache` | `dcache` | Direct-mapped load-miss-allocate, write-through data cache. |

## 4. Tile-Owned Logic

The fetch-integrated tile should own only structural wiring:

```text
frontend imem_if initiator <-> icache front_if target
icache mem_if initiator    <-> tile imem_if initiator
frontend instruction stream -> core instruction stream
core redirect output        -> frontend redirect input
core data request/response  <-> dcache core_if
dcache mem_if initiator     <-> tile dmem_if initiator
core_debug                  <-> core debug_if.core
```

The tile should not own architectural state, cache state, CSR state, pipeline
state, or hidden request buffering in this milestone.

If later data-side or timing closure work needs buffering, the design spec must
be updated with:

```text
new SEQ block
clock/reset domain
buffer full/empty behavior
request drop prevention rule
state diagram
verification cases
```

## 5. Fetch Path Wiring

Expected instruction fetch mapping:

```text
frontend_imem.req_valid -> icache_front.req_valid
frontend_imem.req_addr  -> icache_front.req_addr
frontend_imem.req_write -> icache_front.req_write
frontend_imem.req_size  -> icache_front.req_size
frontend_imem.req_wdata -> icache_front.req_wdata
frontend_imem.req_wstrb -> icache_front.req_wstrb
frontend_imem.req_instr -> icache_front.req_instr
frontend_imem.req_ready <- icache_front.req_ready

frontend_imem.rsp_valid <- icache_front.rsp_valid
frontend_imem.rsp_rdata <- icache_front.rsp_rdata
frontend_imem.rsp_err   <- icache_front.rsp_err
frontend_imem.rsp_ready -> icache_front.rsp_ready
```

The I-cache downstream memory interface is passed outward:

```text
icache.mem_if -> tile.imem_if
```

## 6. Core Instruction And Redirect Wiring

Expected frontend/core mapping:

```text
core.instr_valid_i <- frontend.instr_valid_o
core.instr_ready_o -> frontend.instr_ready_i
core.instr_pc_i    <- frontend.instr_pc_o
core.instr_i       <- frontend.instr_o
core.instr_fault_i <- frontend.instr_fault_o

frontend.redirect_valid_i <- core.redirect_valid_o
frontend.redirect_pc_i    <- core.redirect_pc_o
```

Redirect priority remains inside `frontend` and `core_pipe` according to their
module specs. Tile does not generate extra redirects.

## 7. Data Path Wiring

Core data signals are mapped field-for-field to an internal
`mem_req_rsp_if`. `req_instr` is tied low. The D-cache downstream `mem_if` is
the tile `dmem_if`; no tile-owned state changes transaction timing.

## 8. Sequential State Diagram

The tile wrapper owns no explicit sequential state and no tile-owned FSM.
All sequential state is inside child modules:

```text
frontend -> PC, outstanding fetch, instruction buffer
icache   -> icache_ctrl, icache_tag, icache_data, icache_refill
core     -> core_pipe, core_regfile, core_csr, integrated datapath state
dcache   -> dcache_ctrl, dcache_tag, dcache_data, refill and store sequencers
```

The tile PNG is an L1 timing/ownership block diagram rather than an FSM
diagram. It keeps the COMB wiring separate from every child SEQ block.

## 9. Target Support

The tile itself is target-neutral wiring. Child modules remain responsible for
their own IC and Xilinx Virtex-7 FPGA target-sensitive implementation details.
