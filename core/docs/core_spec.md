# core Spec

## 1. Purpose

`core` is the wasp1 single RV32I + Zicsr machine-mode CPU core.

## 2. ISA Requirements

The core must implement:

```text
RV32I base integer ISA
Zicsr CSR instructions
machine mode only
```

The core must not implement:

```text
M extension
A extension
F/D extensions
C extension
MMU
TLB
page table walker
```

## 3. Execution Requirements

The first complete core must support:

```text
integer register-register operations
integer register-immediate operations
loads and stores
branches and jumps
LUI/AUIPC
JAL/JALR
SYSTEM instructions for ECALL/EBREAK/MRET and CSR access
machine timer interrupt
machine external interrupt
debug halt/resume hooks
```

## 4. Interface Requirements

The core will connect to frontend/cache/tile infrastructure through lightweight
valid/ready request-response interfaces, not directly to TileLink.

## 5. Reset and Trap Requirements

Reset PC must be `OTP_BASE`.

Trap behavior must update machine CSRs consistently with RISC-V machine mode
requirements for supported traps and interrupts.

## 6. Verification Requirements

Core verification must be staged by submodule and then integrated:

```text
ALU operation coverage
decode coverage for supported opcodes
regfile x0 and write/read behavior
branch/jump target and compare coverage
CSR read/write/set/clear coverage
trap and interrupt coverage
load/store request coverage
pipeline hazard/stall/flush coverage
instruction-level directed programs
```
