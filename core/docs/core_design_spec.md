# core Design Spec

## 1. Scope

`core` is the first implemented top-level wrapper for the wasp1 in-order RV32I
+ Zicsr machine-mode core. This milestone intentionally keeps the wrapper thin:
it instantiates `core_int_datapath` and exposes the core boundary expected by
later frontend, cache, tile, debug, and SoC integration.

## 2. Editable Block Diagram

```text
editable source: core/docs/diagrams/core_block.graffle
preview export:  none
detail level:    L1
clock domains:   child SEQ clk=clk_i rst=rst_ni
```

The diagram separates the wrapper boundary, pass-through interface mapping,
child-owned sequential state, child-owned combinational logic, and core output
interfaces. The wrapper itself owns no sequential state and performs no
combinational transformation.

Historical PNG diagram:

```text
core/docs/images/core_state.png
```

New or substantially reworked diagrams should use editable OmniGraffle source
under `core/docs/diagrams/`.

## 3. Implementation

`core` currently has one child instance:

```text
datapath_u: core_int_datapath
```

The wrapper performs no combinational transformation and owns no registers. All
architectural state, pipeline movement, trap CSR updates, load/store request
generation, and hazard control are implemented inside `core_int_datapath` and
its verified submodules.

## 4. Interface Mapping

| `core` interface group | Connected child ports | Notes |
| --- | --- | --- |
| Clock/reset | `clk_i`, `rst_ni` | Direct pass-through. |
| Instruction stream | `instr_valid_i`, `instr_ready_o`, `instr_pc_i`, `instr_i`, `instr_fault_i` | Frontend-owned fetch stream into datapath. |
| Redirect | `redirect_valid_o`, `redirect_pc_o` | Branch/trap/MRET redirect request back to frontend. |
| Data memory | `dmem_req_*`, `dmem_rsp_*` | Valid/ready request-response pass-through to D-cache/tile. |
| Interrupts | `timer_irq_i`, `external_irq_i` | Direct pass-through into machine CSR/trap logic. |
| Debug | `core_debug` | Direct pass-through for halt/resume/step, halted GPR/memory access, and Program Buffer instruction execution. |
| Commit/execute observation | `commit_*`, `ex_*` | Direct pass-through for verification and future retire/debug hooks. |
| Trap/CSR observation | `trap_*`, `mret_taken_o`, `csr_rdata_o` | Direct pass-through for verification and future debug hooks. |
| Hazard observation | `hazard_*` | Direct pass-through from the integrated hazard unit. |
| Unsupported observation | `unsupported_o` | Direct pass-through from integrated decode/writeback gating. |

## 5. Sequential State Diagram

`core` has no wrapper-owned sequential state and no wrapper-owned FSM. Its
sequential behavior is the composition of `core_int_datapath`, especially
`core_pipe`, `core_csr`, and `core_regfile`.

The wrapper diagram is therefore an L1 connection/state ownership diagram rather
than an FSM. The child datapath L3 state diagram remains:

```text
core/docs/images/core_int_datapath_state.png
```

## 6. Target Support

Core RTL is target-neutral synthesizable logic and must lint for:

```text
generic simulation
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```

The wrapper does not contain target-specific logic. Target-specific differences,
when required later, must remain inside documented wrappers or primitives and
must not change programmer-visible core behavior.
