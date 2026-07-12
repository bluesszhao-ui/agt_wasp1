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

The longest current debugger stress regression is:

```text
make -C wasp1 sim-openocd-gdb-long-stress
```

The load/store watchpoint regression is:

```text
make -C wasp1 sim-openocd-gdb-watchpoint
```

All debug targets use the same simulator/OpenOCD harness with different OTP
images, GDB scripts, expected tokens, and log prefixes. The harness streams GDB
output directly to its log and enforces a finite GDB timeout so a missed stop
cannot leave the regression running indefinitely.

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

The long-stress script writes and reads multiple GPRs, checks the same known
`stepi` transition, keeps `hbreak *0x0` and `hbreak *0x4` installed at the same
time, continues through six breakpoint hits, reset-halts again, verifies a
post-reset GPR write/read, and detaches.

The watchpoint script uses a dedicated register-gated OTP loop. Before GDB
writes `t0`, the hart spins at PC `0x0` without touching D-SRAM. GDB then clears
D-SRAM base, writes `t0=0x20000000`, installs `rwatch` for the load and `watch`
for the store, and verifies the word changes from zero to `0x55` only during
the store phase.

## 6. Current Status

The checked-in remote-bitbang smoke and the external OpenOCD/GDB process smoke
are verified. The current debug implementation can connect, halt, read GPRs and
PC, disassemble through Access Memory, execute native `stepi`, use one
OpenOCD/GDB hardware breakpoint in the smoke script, and use two hardware
breakpoints in the stress and long-stress scripts.

Native GDB `stepi` is now part of the automated process smoke. The checked
script reads the current PC, disassembles the instruction through physical
Access Memory, executes `stepi`, rereads PC, and fails if PC did not change.
The stress script additionally installs `hbreak *0x0` and `hbreak *0x4`,
continues, and fails unless GDB stops with the expected PC each time. The
long-stress script keeps both hardware breakpoints resident simultaneously and
checks repeated hits at `0x4`, `0x0`, `0x4`, `0x0`, `0x4`, and `0x0`. The
watchpoint script checks OpenOCD/GDB read and write watchpoint workflows over
the same remote-bitbang path. OpenOCD now observes `progbufsize=4` and uses the
integrated postexec/halted-core execution path. System Bus Access remains a
later debug milestone.

GDB may internally single-step over a RISC-V timing-before data trigger before
presenting the stop. Consequently the script accepts the raw trigger cause or
the normalized step cause and validates the associated PC/memory state. The
core datapath testbench separately checks the raw contract: matched load/store
requests are suppressed and DPC captures the matching instruction PC.

Observed OpenOCD probe:

```text
JTAG tap: wasp1.cpu tap/device found: 0x100001cf
Examined RISC-V core; found 1 harts
hart 0: XLEN=32, misa=0x40000100
datacount=2 progbufsize=4
[wasp1.cpu] Found 2 triggers
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

Observed GDB long stress:

```text
t0             0x11112222
t1             0x33334444
t2             0x55556666
wasp1_gdb_long_reg_pass
wasp1_gdb_long_step_pass
Hardware assisted breakpoint 1 at 0x0
Hardware assisted breakpoint 2 at 0x4
wasp1_gdb_long_dual_hbreak_pass
s0             0x77778888
wasp1_gdb_long_post_reset_pass
[Inferior 1 (Remote target) detached]
```

Observed GDB watchpoints:

```text
Hardware read watchpoint 1: *(unsigned int *)$watch_addr
Value = 0
wasp1_gdb_rwatch_pass
Hardware watchpoint 2: *(unsigned int *)$watch_addr
Old value = 0
New value = 85
wasp1_gdb_watch_pass
wasp1_openocd_gdb_watchpoint PASS
```
