# wasp1 Verification Report

## 1. Commands

```text
make -C wasp1 lint
make -C wasp1 lint-ic
make -C wasp1 lint-fpga-v7
make -C wasp1 sim
make -C wasp1 sim-sw
make -C wasp1 sim-long-boot
make -C wasp1 sim-mixed-irq-dma
make -C wasp1 sim-system-stress
make -C wasp1 sim-random-irq-stress
make -C wasp1 sim-otp-program
make -C wasp1 sim-dma-copy
make -C wasp1 sim-uart-irq
make -C wasp1 sim-uart-rx-irq
make -C wasp1 sim-dma-irq
make -C wasp1 sim-gpio-irq
make -C wasp1 sim-timer-irq
make -C wasp1 sim-rbb-smoke
make -C wasp1 sim-openocd-gdb-smoke
make -C wasp1 sim-openocd-gdb-stress
make -C wasp1 sim-openocd-gdb-long-stress
make -C wasp1 sim-cache-metrics
```

## 2. Results

| Check | Result |
| --- | --- |
| Generic lint | PASS |
| IC-target lint | PASS |
| Virtex-7-target lint | PASS |
| `tb_wasp1` simulation | PASS |
| `tb_wasp1` OTP firmware simulation | PASS |
| `tb_wasp1` long boot firmware simulation | PASS |
| `tb_wasp1` mixed IRQ/DMA firmware simulation | PASS |
| `tb_wasp1` system stress firmware simulation | PASS |
| `tb_wasp1` deterministic-random IRQ stress | PASS |
| `tb_wasp1` OTP programming firmware simulation | PASS |
| `tb_wasp1` DMA copy firmware simulation | PASS |
| `tb_wasp1` UART IRQ firmware simulation | PASS |
| `tb_wasp1` UART RX IRQ firmware simulation | PASS |
| `tb_wasp1` DMA IRQ firmware simulation | PASS |
| `tb_wasp1` GPIO IRQ firmware simulation | PASS |
| `tb_wasp1` timer IRQ firmware simulation | PASS |
| Remote-bitbang socket smoke | PASS |
| Automated OpenOCD/GDB process smoke | PASS |
| Automated OpenOCD/GDB stress | PASS |
| Automated OpenOCD/GDB long stress | PASS |
| Cache/runtime metrics sweep | PASS |

Simulation output:

```text
tb_wasp1 PASS pass_count=9 trap_valid=1 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/hello_uart_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/long_boot_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/mixed_irq_dma_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/system_stress_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/random_irq_stress_otp.hex
Random IRQ stress: state=0xdc745d7e trace=0x00871448 events=13 timer=6 dma=5 gpio=2 event_sum=0x0000184a data_sum=0xa87c2adf PASS
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/otp_program_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/dma_copy_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/uart_irq_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/uart_rx_irq_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/dma_irq_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/gpio_irq_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
tb_wasp1 loaded OTP image: ../llvm_s1/build/smoke/timer_irq_otp.hex
tb_wasp1 PASS pass_count=10 trap_valid=0 trap_cause=0x02 bus_grant_idx=0 dbg_running=1 dbg_halted=0 dbg_dmactive=1
wasp1_rbb_smoke PASS
OpenOCD: hart 0: XLEN=32, misa=0x40000100
OpenOCD: [wasp1.cpu] Found 2 triggers
GDB: registers read, PC visible, stepi PASS, hbreak PASS, detach PASS
wasp1_openocd_gdb_smoke PASS
GDB stress: register write/read PASS, stepi PASS, hbreak 0x0 PASS, hbreak 0x4 PASS
wasp1_openocd_gdb_stress PASS
GDB long stress: multi-register PASS, stepi PASS, dual-resident hbreak PASS, post-reset GPR PASS
wasp1_openocd_gdb_long_stress PASS
WASP1_CACHE_METRICS_ROW label=system_stress cycles=73727 retired=9027 ipc=0.122 cpi=8.167 ic_hit_pct=87.2 dc_hit_pct=92.7
WASP1_CACHE_METRICS_ROW label=random_irq_stress cycles=111571 retired=9960 ipc=0.089 cpi=11.201 ic_hit_pct=77.9 dc_hit_pct=91.4
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
| OpenOCD/GDB process run | Launch `Vwasp1 +rbb-keepalive +WASP1_OTP_HEX`, start OpenOCD remote_bitbang, and run `riscv64-elf-gdb` script | TAP IDCODE, DTM, hart XLEN/misa discovery, two triggers discovered, GDB reset-halt, register reads, PC read, native `stepi`, hardware breakpoint at `0x4`, and detach all complete without OpenOCD/GDB errors | PASS |
| OpenOCD/GDB stress run | Reuse the remote-bitbang process harness with `wasp1_debug_stress.gdb` | GDB writes/reads `t0=0x12345678`, single-steps from `0x4` to `0x0`, deletes/reinstalls breakpoints, and hits hardware breakpoints at `0x0` and `0x4` | PASS |
| OpenOCD/GDB long-stress run | Reuse the remote-bitbang process harness with `wasp1_debug_long_stress.gdb` | GDB writes/reads `t0/t1/t2`, single-steps from `0x4` to `0x0`, installs breakpoints at `0x0` and `0x4` simultaneously, continues through six alternating hits, reset-halts, writes/reads `s0`, and detaches | PASS |
| Cache metrics sweep | Build `tb_wasp1` once and run each generated C OTP image with `+WASP1_METRICS` | `logs/cache_metrics.csv` and `logs/cache_metrics.md` contain one metrics row per firmware image with cycles, retired count, IPC/CPI, and I/D cache hit rates | PASS |
| 3us-3.2us | Continue idle peripheral window | WDG reset remains low; I2C drive enables remain low | PASS |
| 105ns-16.705us | Software-loaded run waits for UART TX FIFO push | OTP firmware fetches from OTP, initializes UART, and writes first byte while JTAG smoke is also checked | PASS |
| 16.705us-17us | Software smoke completion window | UART activity observed and no top-level fatal trap is reported | PASS |
| 105ns-260us | Long boot firmware run | CPU executes one generated OTP image that performs UART output, GPIO output/toggle, D-SRAM pattern stores/reads, polled DMA copy of eight words, polled timer compare, and executable OTP readback; testbench checks completion mailboxes and hardware side effects | PASS |
| 105ns-166us | Mixed IRQ/DMA firmware run | CPU enables DMA IRQ ID 5 and GPIO IRQ ID 4 together, starts DMA, testbench drives GPIO[0] high after firmware ready, INTC claims DMA before GPIO by priority, handler clears both sources, and testbench checks copied D-SRAM data plus final IRQ deassertion | PASS |
| 105ns-737us | System stress firmware run | CPU runs six polling rounds of D-SRAM seed/readback, DMA copy of eight words, timer compare polling, GPIO writes/toggles, UART TX pushes, and executable OTP readback; testbench checks checksum, final DMA buffers, GPIO value, status accumulators, and final deasserted IRQ state | PASS |
| 105ns-1ms | Deterministic-random IRQ stress | Fixed seed `0x1a2b3c4d` selects 12 timer, DMA, GPIO, or concurrent timer+DMA rounds; testbench performs two GPIO request/ack handshakes and independently checks selector trace `0x00871448`, 13 events (timer 6, DMA 5, GPIO 2), event checksum `0x0000184a`, DMA checksum `0xa87c2adf`, UART progress, and final IRQ deassertion | PASS |
| 105ns-33us | OTP programming firmware run | Startup copies `.fasttext` to I-SRAM; CPU executes the programming routine from I-SRAM and programs OTP word `0x00003fa0` to `0x13572468` with `done=1` and `error=0` | PASS |
| 105ns-21us | DMA copy firmware run | CPU seeds D-SRAM source words at `0x20003000`, starts DMA to copy four words to `0x20003040`, and the testbench observes matching destination words with `done=1`, `error=0`, and `irq=1` | PASS |
| 105ns-75us | UART IRQ firmware run | CPU enables UART TX-empty IRQ ID 2 in INTC, services one machine external interrupt, claims/completes IRQ 2, clears UART sticky TX-empty status, disables UART TX IRQ enable, and returns to idle | PASS |
| 105ns-148us | UART RX IRQ firmware run | CPU arms UART RX-available IRQ ID 2, testbench drives one external UART RX byte, C trap handler reads UART DATA and clears RX-available; firmware then arms overrun-only IRQ, testbench drives multiple serial frames, and handler clears sticky RX-overrun with UART/INTC IRQs deasserted | PASS |
| 105ns-83us | DMA IRQ firmware run | CPU enables DMA IRQ ID 5 in INTC, starts DMA, services one machine external interrupt, claims/completes IRQ 5, clears the DMA IRQ source, and returns to idle with copied D-SRAM destination words | PASS |
| 105ns-87us | GPIO IRQ firmware run | CPU configures GPIO bit 0 as level-high source, enables GPIO IRQ ID 4 in INTC, testbench drives `gpio_in[0]` high, C trap handler claims/completes IRQ 4, clears GPIO sticky status, and returns to idle | PASS |
| 105ns-50us | Timer IRQ firmware run | CPU programs `mtime/mtimecmp`, enables MTIE/MIE, services one machine timer interrupt, writes trap mailbox values in D-SRAM, disables timer IRQ, and returns to idle | PASS |

## 4. Residual Risk

This is an integration smoke test, not a full system software test. The
OpenOCD/GDB process path is now automated and verified for connect, halt,
register read, PC read, PC disassembly through Access Memory, native GDB
`stepi` with PC-change assertion, an execute-address hardware breakpoint
through `hbreak`, and detach over remote-bitbang JTAG. GDB stress targets now
also cover GPR write/read, hardware breakpoint delete/reinstall, two hardware
breakpoint hits at separate OTP addresses, simultaneous two-breakpoint
residency, repeated alternating hits, and post-reset GPR access.
The CPU-controlled OTP programming
register flow is now covered by a directed firmware smoke test. End-to-end DMA
memory-copy through real D-SRAM contents is also covered by generated firmware.
The long boot firmware image now combines UART, GPIO, D-SRAM, DMA, timer, and
OTP readback activity in one generated-image run.
The system stress firmware image repeats D-SRAM, DMA, timer, GPIO, UART, and
OTP-read activity over six polling rounds and checks accumulated status and
checksum mailboxes at the top level.
The deterministic-random IRQ image now covers 12 fixed-seed rounds with timer,
DMA, GPIO, and concurrent timer+DMA choices. Its independent testbench
scoreboard checks the complete PRNG trace, per-source counts, order-independent
event and DMA-data checksums, GPIO request/ack handshakes, and final IRQ state.
The cache metrics sweep now records current I-cache/D-cache hit rates and
cycles/retired/IPC/CPI for all generated C firmware images.
The mixed IRQ/DMA firmware image now combines DMA master activity with two INTC
external sources and verifies DMA-before-GPIO priority order in software.
The UART TX-empty, UART RX-available/RX-overrun, DMA, and GPIO external
interrupt paths are covered through INTC claim/complete and MEIP. The machine
timer interrupt path is covered by a generated firmware image that returns
through the C trap handler. Remaining top-level work includes richer debug
operations such as data/load/store triggers, optional SBA/program-buffer flows,
and multi-seed or longer-duration randomized software campaigns.
