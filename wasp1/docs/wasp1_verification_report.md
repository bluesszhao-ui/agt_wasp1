# wasp1 Verification Report

## 1. Commands

```text
make -C wasp1 lint
make -C wasp1 lint-ic
make -C wasp1 lint-fpga-v7
make -C wasp1 sim
make -C wasp1 sim-sw
make -C wasp1 sim-otp-program
make -C wasp1 sim-rbb-smoke
openocd -f wasp1/dv/openocd/wasp1_remote_bitbang.cfg -c shutdown
riscv64-elf-gdb -x wasp1/dv/gdb/wasp1_debug_smoke.gdb
```

## 2. Results

| Check | Result |
| --- | --- |
| Generic lint | PASS |
| IC-target lint | PASS |
| Virtex-7-target lint | PASS |
| `tb_wasp1` simulation | PASS |
| `tb_wasp1` OTP firmware simulation | PASS |
| `tb_wasp1` OTP programming firmware simulation | PASS |
| Remote-bitbang socket smoke | PASS |
| OpenOCD process smoke | PASS |
| GDB process smoke | PASS |

Simulation output:

```text
tb_wasp1 PASS pass_count=9 trap_valid=1 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/hello_uart_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/otp_program_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
wasp1_rbb_smoke PASS
OpenOCD: hart 0: XLEN=32, misa=0x40000100
GDB: registers read, pc=0x00000000, detach PASS
```

## 3. Time-Sequenced Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-40ns | Hold reset active for four 10ns cycles | Integrated state resets; IO defaults are benign | PASS |
| 41ns | Check reset outputs | UART TX idle high, I2C drive enables low, GPIO output/enables zero, WDG reset low | PASS |
| 45ns-55ns | Release reset and allow one clock | SoC exits reset without unknown top-level control behavior | PASS |
| 55ns-95ns | Wait for core AHB master transfer | Core-side bridge/fabric path observes valid transfer | PASS |
| 95ns-105ns | Wait for debug status | Core debug status reports running or halted | PASS |
| 105ns-3us | Bit-bang JTAG IDCODE, DTMCS, `dmcontrol.dmactive`, and `dmstatus` | JTAG pins reach integrated Debug Module; `dbg_dmactive_o=1` | PASS |
| Remote-bitbang run | Launch `Vwasp1` socket harness and connect Python remote-bitbang client | TCP JTAG path returns IDCODE/DTMCS and DMI `dmstatus` success | PASS |
| OpenOCD process run | Launch `Vwasp1 +rbb-keepalive` and connect OpenOCD remote_bitbang | TAP IDCODE, DTM, single hart, XLEN=32, and RV32I `misa` are detected | PASS |
| GDB process run | Keep OpenOCD GDB server on `localhost:3333` and run `riscv64-elf-gdb` script | GDB connects, reset-halts, reads GPRs and PC, detaches cleanly | PASS |
| 3us-3.2us | Continue idle peripheral window | WDG reset remains low; I2C drive enables remain low | PASS |
| 105ns-16.705us | Software-loaded run waits for UART TX FIFO push | OTP firmware fetches from OTP, initializes UART, and writes first byte while JTAG smoke is also checked | PASS |
| 16.705us-17us | Software smoke completion window | UART activity observed and no top-level fatal trap is reported | PASS |
| 105ns-33us | OTP programming firmware run | Startup copies `.fasttext` to I-SRAM; CPU executes the programming routine from I-SRAM and programs OTP word `0x00003fa0` to `0x13572468` with `done=1` and `error=0` | PASS |

## 4. Residual Risk

This is an integration smoke test, not a full system software test. The
OpenOCD/GDB process path is now verified for connect, halt, register read, PC
read, and detach over remote-bitbang JTAG. The CPU-controlled OTP programming
register flow is now covered by a directed firmware smoke test. Remaining
top-level work includes end-to-end DMA memory-copy through real slave contents,
interrupt-driven software, longer SoC boot tests from `llvm_s1` output, and
richer debug operations such as single-step, breakpoints, abstract memory
access, and true core DPC capture.
