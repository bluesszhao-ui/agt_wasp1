# core_int_datapath Design Spec

## 1. Scope

`core_int_datapath` is a staged integration block. It is not the final core top;
it exists to verify the first executable integer, load/store, CSR, trap, and
interrupt datapath with load-use hazard control before full EX/WB forwarding mux
integration.

## 2. Editable Block Diagram

```text
editable source: core/docs/diagrams/core_int_datapath_block.graffle
preview export:  none
detail level:    L3
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The diagram separates frontend, pipe, decode/hazard, regfile, execute, CSR/debug
state, writeback/trap/redirect, data-memory, IRQ/debug input, and debug-control
logic. Long writeback and redirect relationships are documented in the blocks
and in the datapath text below; the diagram keeps only the redirect-to-pipe
feedback wire explicit so the flush priority is visually clear without creating
a line bundle.

## 3. Datapath

`core_pipe` supplies the execute/writeback slot. This milestone decodes the EX
slot directly and reads the register file using the decoded source fields.

`core_pipe` now also contains a verified halted-core debug injection slot and
ID/EX source tags. This datapath milestone ties the injection request inactive;
the next Program Buffer integration step will connect `debug_if` and consume
`ex_debug` for completion/error isolation without changing normal execution.

ALU operand selection:

```text
AUIPC lhs = ex_pc
normal lhs = rs1_data
immediate rhs = dec_imm
register rhs = rs2_data
```

Writeback source selection:

```text
LUI       -> CORE_WB_IMM
JAL/JALR  -> CORE_WB_PC4
load      -> CORE_WB_LOAD
CSR       -> CORE_WB_CSR
AUIPC     -> ALU result ex_pc + imm
ALU ops   -> ALU result
```

Unsupported classes and faults drive the `core_wb` fault input so register
writeback is suppressed.

Control-flow selection:

```text
taken branch -> redirect to ex_pc + B immediate
JAL          -> redirect to ex_pc + J immediate and write rd = ex_pc + 4
JALR         -> redirect to (rs1 + I immediate) with bit 0 cleared and write rd = ex_pc + 4
not-taken    -> no redirect and no register writeback
```

Redirect is gated by `ex_valid`, fetch fault, and illegal decode status. When a
redirect is asserted, `core_pipe` flushes younger IF/ID and EX/WB state on the
next active clock edge and forwards the redirect target to `frontend`.

Load/store selection:

```text
effective address = rs1_data + decoded immediate
load              -> issue read request, wait for response, write formatted load data to rd
store             -> issue write request with lane-shifted data/byte strobes and wait for response
misaligned access -> no data request, no register writeback, lsu_fault_o=1
response error    -> request is observable, no register writeback, lsu_fault_o=1
```

The data-memory interface uses one in-order outstanding valid/ready transaction:

```text
request fire  = dmem_req_valid_o && dmem_req_ready_i
response fire = dmem_rsp_valid_i && dmem_rsp_ready_o
```

For aligned loads and stores, `core_int_datapath` holds IF/ID and EX/WB while a
request is not yet accepted or while an accepted request is waiting for a
response. Load writeback and response-error observation occur only on response
fire. Misaligned accesses are local faults and do not issue a data request.

CSR/trap selection:

```text
CSR instruction -> old CSR value writes rd, CSR state updates on clock edge
illegal CSR     -> illegal-instruction trap, no rd writeback
ECALL/EBREAK    -> trap to mtvec, mepc captures faulting PC
MRET            -> redirect to mepc, mstatus.MIE restored from MPIE
enabled IRQ     -> interrupt trap to mtvec with interrupt mcause bit set
```

Trap/MRET redirects have priority over branch/JAL/JALR redirects. Trap entry
updates `mepc`, `mcause`, `mtval`, and `mstatus` in `core_csr` on the same clock
edge that `core_pipe` flushes younger slots.

Hazard selection:

```text
ID uses rs1/rs2 matching EX load rd -> stall fetch/decode and bubble execute
EX forwarding indication            -> exposed for later operand mux integration
WB forwarding indication            -> exposed for later operand mux integration
```

The current staged datapath still relies on register-file timing for non-load
adjacent dependencies. The forwarding decision outputs are observable now, and
the actual operand forwarding muxes will be added when the final EX/WB split is
introduced.

## 4. Debug Hook Behavior

The datapath instantiates `core_debug_ctrl` and uses its control outputs as
follows:

```text
debug_stop_fetch  -> added to pipe_fetch_stall
debug_freeze_pipe -> added to pipe_decode_stall and blocks execute bubble update
debug_halted      -> enables halted GPR request ready
debug_running     -> exported through debug_if.core
debug_next_pc_q   -> tracks the next PC implied by fetch/retire
debug_dpc_q       -> exported through debug_if.core as captured DPC
debug_dcsr_cause_q -> exported through debug_if.core as DCSR cause
```

The pipeline drains rather than being frozen immediately:

```text
halt request visible:
  stop accepting new frontend instructions immediately
  allow existing IF/ID, EX/WB, and LSU response work to retire
  when pipe is idle, enter halted state

halted state:
  instr_ready_o remains deasserted
  dpc reports the PC where execution will resume
  GPR requests are accepted one at a time
  read response captures regfile read data
  write request uses the regfile write port
  x0 remains hardwired to zero through core_regfile behavior

resume:
  leaves halted state after any pending GPR response is consumed

execute trigger:
  compares the ID-stage PC with every core_debug.trigger_execute_addr slot
  requires at least one core_debug.trigger_execute_valid slot and a drainable older EX/LSU state
  redirects fetch back to the matched PC
  updates debug_next_pc_q/debug_dcsr_cause_q before Debug Mode capture
  prevents the matched instruction from retiring before halt

load/store trigger:
  compares the EX-stage LSU effective address with every core_debug.trigger_data_addr slot
  qualifies each slot independently with trigger_load_valid or trigger_store_valid
  gives a matched data trigger priority over LSU request, misalignment, response fault, and retirement
  suppresses dmem_req_valid_o and lsu_req_fire in the match cycle
  redirects to ex_pc so core_pipe flushes the matched instruction without side effects
  records ex_pc as debug_next_pc_q and DCSR cause=trigger
  after trigger clear and resume, refetches and executes the matched instruction once
```

If a data trigger and a younger execute trigger are visible together, the older
EX-stage data trigger supplies DPC. Debug Access Memory requests are generated
only while halted and are not subject to architectural load/store triggers.

The halted GPR path intentionally reuses register-file port 1 and the single
write port because the pipeline is drained while debug access is allowed. This
avoids adding a second architectural write path.

DPC capture is intentionally tied to existing in-order commit information:

```text
first accepted fetch before retirement -> seed debug_next_pc_q with instr_pc_i
normal retiring instruction             -> debug_next_pc_q = ex_pc + 4
taken branch/JAL/JALR retire            -> debug_next_pc_q = branch target
trap or MRET redirect retire            -> debug_next_pc_q = trap/MRET target
execute trigger match                    -> debug_next_pc_q = matched ID PC
halted Debug Mode                       -> debug_dpc_q captures debug_next_pc_q
```

The captured value is a resume PC, not a history trace PC. The Debug Module
returns it through the abstract `dpc` CSR read path used by OpenOCD/GDB.

DCSR cause state is kept beside DPC state:

```text
halt_req_i accepted   -> cause=3, halt request
step resume requested -> cause=4, step
execute trigger match -> cause=2, trigger
```

## 5. Sequential State Diagram

Historical PNG:

```text
core/docs/images/core_int_datapath_state.png
```

New debug-control FSM editable source:

```text
core/docs/diagrams/core_debug_ctrl_fsm.graffle
```

The sequential state comes from the instantiated `core_pipe` and
`core_regfile`:

```text
Reset:
  core_pipe IF/ID and EX/WB slots invalid
  core_regfile x1..x31 <- 0

Each accepted frontend instruction stream beat:
  core_pipe captures instruction into IF/ID
  old IF/ID advances to EX/WB

Each execute/writeback cycle:
  EX instruction is decoded
  register operands are read
  ALU/writeback data is computed
  branch/JAL/JALR target is computed
  load/store request and load writeback data are computed
  CSR read/write data and trap priority are computed
  ID source registers are compared with EX/WB destinations
  if aligned load/store waits for request or response:
    core_pipe holds IF/ID and EX/WB
    dmem_req_valid_o remains asserted until request fire
    dmem_rsp_ready_o remains asserted while waiting for response
  if load-use hazard:
    core_pipe holds fetch/decode and injects an EX bubble after load response
  if load/store fault:
    architectural writeback is suppressed
  if trap or MRET redirects:
    core_pipe blocks instruction stream acceptance for the redirect cycle
    core_pipe flushes younger slots and forwards mtvec/mepc target PC
  if branch/JAL/JALR redirects:
    core_pipe blocks instruction stream acceptance for the redirect cycle
    core_pipe flushes younger slots and forwards target PC
  if retirement changes the architectural next PC:
    debug_next_pc_q updates to the same resume target used by the frontend
  if valid and supported and rd!=x0:
    core_regfile writes rd on the next clock edge

Debug halt/resume state:
  core_debug_ctrl reset state is running
  halt request stops new fetch and waits for the pipe to drain
  halted state captures debug_next_pc_q into debug_dpc_q
  halted state freezes the empty pipeline and enables GPR debug access
  resume exits halted after pending GPR response traffic clears
```

The integrated regfile instance disables same-cycle bypass to avoid a
writeback/read combinational loop through the integrated datapath. Adjacent
integer dependencies are still verified against the staged pipeline timing.

## 6. Target Support

The module is target-neutral synthesizable RTL and uses no IC or Virtex-7
specific primitive.
