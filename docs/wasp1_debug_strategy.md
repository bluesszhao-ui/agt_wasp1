# wasp1 Debug Strategy

## 1. Goal

wasp1 debug targets compatibility with OpenOCD and GDB through a RISC-V External
Debug Spec 0.13.x style implementation.

The final project scope also includes an FTDI-based external hardware debugger
so the same OpenOCD/GDB flow can be used on FPGA boards and final hardware.

## 2. Debug Subsystem

```text
debug
  jtag_tap
  riscv_dtm
  riscv_dm
  debug_halt_ctrl
  debug_reg_access
  debug_mem_access
  debug_abstract_cmd
  debug_trigger
  debug_progbuf
```

## 3. Implementation Stages

| Stage | Scope |
| ---: | --- |
| 1 | JTAG DTM, DMI, dmcontrol, dmstatus, halt/resume, basic GPR access |
| 2 | abstract command, DPC readback, DCSR.step single-step |
| 3 | physical Access Memory through halted core and native GDB `stepi` smoke |
| 4 | one execute-address hardware breakpoint through Debug Spec trigger CSRs |
| 5 | FT2232H external debugger pinout/OpenOCD config, schematic/PCB, FPGA/board bring-up |
| 6 | longer debugger stress, multiple triggers, optional system bus or program-buffer memory access |

## 4. Core Interaction

The core must support:

```text
halt request
resume request
halted status
register access path
memory access path
execute-address trigger entry path
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
single-step one instruction through DCSR.step
read memory through halted-core Access Memory
hit one hardware breakpoint through hbreak
```

Physical Access Memory, native `stepi`, and one hardware breakpoint are now
part of the automated remote-bitbang OpenOCD/GDB smoke. Multiple triggers, data
triggers, System Bus Access, and program-buffer execution remain later-stage
targets.

## 6. External FTDI Debugger

The final hardware debugger is a companion board, not part of the wasp1 chip
RTL. The planned baseline is:

```text
FT2232H channel A -> MPSSE JTAG -> wasp1 JTAG pins
FT2232H channel B -> UART -> wasp1 UART / OTP programming flow
```

The chip-side debug contract must remain independent of whether OpenOCD reaches
wasp1 through:

```text
remote_bitbang Verilator simulation
FT2232H hardware debugger
other OpenOCD-compatible JTAG adapters
```

The FTDI-specific collateral is tracked under `ftdi_debugger/`.

The current FTDI collateral includes the stage-1 FT2232H pinout, a reference
OpenOCD FTDI configuration, and a static checker:

```text
make -C ftdi_debugger lint
```
