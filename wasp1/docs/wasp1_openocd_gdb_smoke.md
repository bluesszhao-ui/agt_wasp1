# wasp1 OpenOCD/GDB Smoke Setup

## 1. Scope

This document describes the first OpenOCD/GDB-facing debug setup for wasp1.
The current verified path is:

```text
OpenOCD remote_bitbang adapter
  -> Verilator remote-bitbang socket
  -> wasp1 top JTAG pins
  -> debug_jtag
  -> debug_jtag_dtm
  -> debug
  -> tile core_debug
```

## 2. Build and Run Remote-Bitbang Simulation

Installed tool versions used for the 2026-07-03 smoke:

```text
OpenOCD 0.12.0
GNU gdb 17.2, target riscv64-elf
```

`riscv64-elf-gdb` is used because the Homebrew RISC-V GDB package is named for
the multi-XLEN target; it can debug this RV32 target after OpenOCD reports
`XLEN=32`.

Build the socket-capable Verilator harness:

```text
make -C wasp1 sim-rbb-build
```

Run the simulator:

```text
wasp1/build/obj_wasp1_rbb/Vwasp1 +rbb-port=9824 +rbb-keepalive
```

The simulator listens on `127.0.0.1:9824`.

## 3. Local Remote-Bitbang Smoke

The repository includes a Python smoke client that uses the same socket
pin-level protocol as OpenOCD's remote-bitbang adapter:

```text
make -C wasp1 sim-rbb-smoke
```

It checks:

```text
JTAG IDCODE
DTMCS version/abits
DMI write dmcontrol.dmactive
DMI read dmstatus
```

## 4. OpenOCD

Run:

```text
openocd -f wasp1/dv/openocd/wasp1_remote_bitbang.cfg
```

The OpenOCD config expects:

```text
remote_bitbang host localhost
remote_bitbang port 9824
JTAG IR length 5
expected IDCODE 0x100001cf
RISC-V target type
```

## 5. GDB

After OpenOCD is running, run:

```text
riscv64-elf-gdb -x wasp1/dv/gdb/wasp1_debug_smoke.gdb
```

The script connects to OpenOCD on `localhost:3333`, requests reset-halt, prints
registers, detaches, and exits.

## 6. Current Limitation

The checked-in remote-bitbang smoke and the external OpenOCD/GDB process smoke
are verified. The current debug implementation is still stage-1: GDB can
connect, halt, read GPRs and PC, single-step through the internal DCSR.step
path, and detach, but breakpoints, program buffer execution and abstract memory
access are future milestones.

Observed OpenOCD probe:

```text
JTAG tap: wasp1.cpu tap/device found: 0x100001cf
Examined RISC-V core; found 1 harts
hart 0: XLEN=32, misa=0x40000100
```

Observed GDB smoke:

```text
0x00000000 in ?? ()
pc             0x0  0x0
[Inferior 1 (Remote target) detached]
```
