# tile Design Spec

## 1. Scope

`tile` integrates the already implemented `frontend`, `core`, and `icache`
modules into the first CPU tile instruction path.

The first RTL milestone should not instantiate `dcache` yet. The current core
data interface is not ready/valid, while `dcache` is multi-cycle ready/valid.
Connecting them through a purely combinational adapter would make backpressure
and load-response timing ambiguous.

## 2. Planned Block Diagram

```text
Legend:
  SEQ  = sequential state, pale green in generated diagrams/PPT
  COMB = combinational logic, pale amber/yellow
  IF   = external/interface boundary, pale blue

Clock/reset domain:
  all SEQ blocks below use clk=clk_i, rst=rst_ni

 IF clk_i/rst_ni/boot_pc/irq/cache control
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
|  IF dmem scalar core data interface remains exposed/deferred           |
|  IF commit/trap/hazard/debug-observe outputs                           |
+------------------------------------------------------------------------+
```

## 3. Child Instances

| Instance | Module | Purpose |
| --- | --- | --- |
| `u_frontend` | `frontend` | Owns boot PC, sequential fetch PC, redirect reload, request issue, and instruction buffering. |
| `u_icache` | `icache` | Instruction fetch cache behind the frontend request stream. |
| `u_core` | `core` | RV32I+Zicsr machine-mode execution and observation outputs. |

Deferred child:

| Module | Reason deferred |
| --- | --- |
| `dcache` | Requires a core LSU/data-memory ready/valid handshake or a specified tile-owned sequential adapter. |

## 4. Tile-Owned Logic

The fetch-integrated tile should own only structural wiring:

```text
frontend imem_if initiator <-> icache front_if target
icache mem_if initiator    <-> tile imem_if initiator
frontend instruction stream -> core instruction stream
core redirect output        -> frontend redirect input
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

## 7. Data Path Status

The current tile milestone should expose the current core scalar data-memory
ports for observation or test hookup, but must not claim D-cache integration is
complete.

The next required design work before D-cache tile RTL is:

```text
core_lsu/core_int_datapath/core wrapper:
  add request-ready and response-valid/ready semantics
  hold pipeline state while an outstanding load/store is waiting
  define store completion and error timing
  update verification plans and reports
```

## 8. Sequential State Diagram

The first tile wrapper owns no explicit sequential state and no tile-owned FSM.
All sequential state is inside child modules:

```text
frontend -> PC, outstanding fetch, instruction buffer
icache   -> icache_ctrl, icache_tag, icache_data, icache_refill
core     -> core_pipe, core_regfile, core_csr, integrated datapath state
```

The tile diagram is therefore an L1 state ownership diagram rather than an FSM.
No new PNG state diagram is required until tile-owned registers or an FSM are
introduced.

## 9. Target Support

The tile itself is target-neutral wiring. Child modules remain responsible for
their own IC and Xilinx Virtex-7 FPGA target-sensitive implementation details.
