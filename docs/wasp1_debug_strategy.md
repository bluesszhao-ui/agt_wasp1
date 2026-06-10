# wasp1 Debug Strategy

## 1. Goal

wasp1 debug targets compatibility with OpenOCD and GDB through a RISC-V External
Debug Spec 0.13.x style implementation.

## 2. Debug Subsystem

```text
debug
  jtag_tap
  riscv_dtm
  riscv_dm
  debug_rom
  debug_halt_ctrl
  debug_reg_access
  debug_mem_access
  debug_abstract_cmd
  debug_progbuf
```

## 3. Implementation Stages

| Stage | Scope |
| ---: | --- |
| 1 | JTAG DTM, DMI, dmcontrol, dmstatus, halt/resume, basic GPR access |
| 2 | abstract command, system bus or program buffer memory access |
| 3 | single step, breakpoints, robust GDB workflow |

## 4. Core Interaction

The core must support:

```text
halt request
resume request
halted status
register access path
memory access path
debug exception or debug entry behavior
```

## 5. OpenOCD Bring-Up Target

The first debug bring-up target is for OpenOCD to:

```text
scan JTAG chain
identify DTM
read dmstatus
halt the hart
read and write GPRs
resume the hart
```

Memory access and GDB single-step are later-stage validation targets.
