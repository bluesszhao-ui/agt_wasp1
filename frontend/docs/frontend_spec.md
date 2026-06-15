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

## 4. ISA Assumptions

wasp1 implements RV32I without the compressed extension. Sequential instruction
fetch advances by 4 bytes. Misaligned targets must be observable so later fetch
or trap logic can preserve architectural exception behavior.

## 5. Target Requirements

Frontend RTL must be target-neutral synthesizable SystemVerilog and lint for:

```text
generic simulation
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
