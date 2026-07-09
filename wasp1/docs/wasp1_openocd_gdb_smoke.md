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

Installed tool versions used for the 2026-07-06 smoke:

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
wasp1/build/obj_wasp1_rbb/Vwasp1 +rbb-port=9824 +rbb-keepalive +WASP1_OTP_HEX=llvm_s1/build/smoke/hello_uart_otp.hex
```

The simulator listens on `127.0.0.1:9824`.

The preferred one-command regression is:

```text
make -C wasp1 sim-openocd-gdb-smoke
```

This target builds the remote-bitbang harness, runs `llvm_s1 smoke` to create
the generated OTP images, starts the simulator, starts OpenOCD, runs the GDB
script, and then tears the child processes down.

The longer debugger stress regression is:

```text
make -C wasp1 sim-openocd-gdb-stress
```

It uses the same simulator/OpenOCD harness with a different GDB script and log
prefix.

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
remote_bitbang port 9824 by default, or Tcl variable `RBB_PORT`
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
registers, checks PC visibility, executes one native `stepi`, sets one hardware
breakpoint with `hbreak *0x4`, continues until the breakpoint hits, detaches,
and exits.

The stress script additionally writes and reads one GPR through GDB, checks one
known `stepi` PC transition on the two-instruction OTP loop, deletes/reinstalls
hardware breakpoints, and hits both `hbreak *0x0` and `hbreak *0x4`.

## 6. Current Status

The checked-in remote-bitbang smoke and the external OpenOCD/GDB process smoke
are verified. The current debug implementation can connect, halt, read GPRs and
PC, disassemble through Access Memory, execute native `stepi`, use one
OpenOCD/GDB hardware breakpoint, and detach.

Native GDB `stepi` is now part of the automated process smoke. The checked
script reads the current PC, disassembles the instruction through physical
Access Memory, executes `stepi`, rereads PC, and fails if PC did not change.
The same script then installs `hbreak *0x4`, continues, and fails unless GDB
stops with PC equal to `0x4`. Program buffer execution, System Bus Access, and
multiple/data trigger workflows remain later debug milestones.

Observed OpenOCD probe:

```text
JTAG tap: wasp1.cpu tap/device found: 0x100001cf
Examined RISC-V core; found 1 harts
hart 0: XLEN=32, misa=0x40000100
[wasp1.cpu] Found 1 triggers
```

Observed GDB smoke:

```text
wasp1_gdb_stepi_pass
Hardware assisted breakpoint 1 at 0x4
Breakpoint 1, 0x00000004 in ?? ()
dcsr           0x40000083
pc             0x4  0x4
wasp1_gdb_hbreak_pass
[Inferior 1 (Remote target) detached]
```

Observed GDB stress:

```text
t0             0x12345678
wasp1_gdb_reg_write_read_pass
wasp1_gdb_stress_stepi_pass
Hardware assisted breakpoint 1 at 0x0
wasp1_gdb_stress_hbreak0_pass
Hardware assisted breakpoint 2 at 0x4
wasp1_gdb_stress_hbreak4_pass
[Inferior 1 (Remote target) detached]
```
