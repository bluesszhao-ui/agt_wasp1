# core Spec

## 1. Purpose

`core` is the first-level wasp1 single RV32I + Zicsr machine-mode CPU module.
It establishes the stable core boundary used by later frontend, cache, tile,
debug, and SoC integration stages.

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

The implemented first core wrapper must preserve all behavior implemented by
`core_int_datapath`:

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
load-use hazard stall observation
```

Debug halt/resume hooks remain a later `debug` and `tile` integration item.

## 4. Interface Requirements

The core connects to surrounding frontend/cache/tile infrastructure through
lightweight interfaces:

```text
instruction side: frontend-owned valid/ready instruction stream with PC/fault
redirect side: branch/trap/MRET redirect valid + target PC back to frontend
data side: request valid/address/write/size/wdata/wstrb, response rdata/error
interrupt side: timer_irq_i and external_irq_i
observation side: commit, execute, trap, CSR, hazard, unsupported indicators
```

The core does not directly expose TileLink or AHB-Lite. Bus/cache translation is
owned by later frontend/cache/tile modules.

## 5. Reset and Trap Requirements

Reset PC is supplied to `frontend`, not to `core`. SoC integration must drive
the frontend boot PC to the executable OTP reset vector, then deliver fetched
instructions to `core` through the instruction stream.

Trap behavior must update machine CSRs consistently with RISC-V machine mode
requirements for supported traps and interrupts.

## 6. Target Requirements

`core` is target-neutral synthesizable logic. It must lint with:

```text
generic simulation
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```

Target macros must not change ISA, trap, interrupt, or interface behavior.

## 7. Verification Requirements

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
wrapper-level port pass-through and integrated smoke coverage
```
