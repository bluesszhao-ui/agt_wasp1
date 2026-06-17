# frontend Spec

## 1. Purpose

`frontend` is the first-level instruction frontend module family for wasp1. It
will own program-counter generation, redirect handling, instruction fetch
request/response control, and a small instruction buffer before the core
pipeline consumes instructions.

## 2. Required Submodules

```text
frontend
frontend_pc
frontend_fetch
frontend_redirect
frontend_ibuf
```

## 3. Interface Requirements

The frontend must connect between the core-side lightweight valid/ready fetch
interface and the later I-cache/tile instruction-side interface.

The implemented first submodule, `frontend_pc`, provides:

```text
boot PC reset loading
sequential PC + 4 advance on accepted fetch
redirect target capture
stall/backpressure hold
misaligned PC indication
```

The implemented `frontend_fetch` submodule provides:

```text
PC request to instruction-memory request translation
one outstanding instruction fetch
misaligned PC local fault response
flush-based stale response drop
memory error propagation
```

The implemented `frontend_ibuf` submodule provides:

```text
two-entry instruction response buffering
FIFO ordering from fetch response to core side
fault and misaligned-PC metadata preservation
full/empty status
flush-based queue clear
```

The implemented `frontend` top provides:

```text
frontend_pc, frontend_fetch, and frontend_ibuf integration
single-source redirect capture and flush
instruction memory/cache request interface
buffered core-side instruction response interface
```

`frontend_redirect` remains a planned arbitration leaf for the later stage where
branch, trap, debug, and possible external redirect sources are connected at the
same boundary.

## 4. Top-Level Interface Requirements

The `frontend` top must expose:

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | Frontend clock. |
| `rst_ni` | input | Active-low asynchronous reset. |
| `boot_pc_i` | input | Reset PC, normally OTP base. |
| `stall_i` | input | Suppresses new PC request generation. |
| `redirect_valid_i` | input | Redirect request and flush qualifier. |
| `redirect_pc_i` | input | Redirect target PC. |
| `instr_valid_o` | output | Buffered instruction response is valid. |
| `instr_ready_i` | input | Core side accepts the instruction response. |
| `instr_pc_o` | output | PC associated with the instruction response. |
| `instr_o` | output | Instruction word. |
| `instr_fault_o` | output | Fetch fault flag. |
| `instr_misaligned_o` | output | Fetch fault is due to a misaligned PC. |
| `imem_if` | initiator | Instruction memory/cache request-response interface. |

## 5. ISA Assumptions

wasp1 implements RV32I without the compressed extension. Sequential instruction
fetch advances by 4 bytes. Misaligned targets must be observable so later fetch
or trap logic can preserve architectural exception behavior.

## 6. Target Requirements

Frontend RTL must be target-neutral synthesizable SystemVerilog and lint for:

```text
generic simulation
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
