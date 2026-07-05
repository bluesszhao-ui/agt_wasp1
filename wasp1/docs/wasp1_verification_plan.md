# wasp1 Verification Plan

## 1. Scope

The top-level verification target is `wasp1`. Module-level functional coverage
remains owned by each lower-level module; this plan focuses on integration
elaboration, reset connectivity, and first fetch-path activity.

## 2. Test Items

| Item | Goal | Method |
| --- | --- | --- |
| Generic lint | Check full SoC elaboration | Run Verilator lint on 63 integrated modules. |
| IC target lint | Check IC macro path | Run lint with `WASP1_TARGET_IC`. |
| Virtex-7 lint | Check FPGA macro path | Run lint with `WASP1_TARGET_FPGA_XILINX_VIRTEX7`. |
| Reset defaults | Check benign IO after reset | Hold reset for four 10ns cycles and inspect UART/I2C/GPIO/WDG outputs. |
| Fetch-path activity | Check tile -> bridge -> fabric path | Wait for the core AHB master to issue a valid transfer after reset. |
| OTP firmware smoke | Check generated `llvm_s1` image can execute from OTP | Load `hello_uart_otp.hex`, wait for firmware to push the first UART TX byte. |
| Long boot firmware smoke | Check longer generated-image mixed peripheral path | Load `long_boot_otp.hex`, run UART output, GPIO writes/toggle, D-SRAM stores/loads, polled DMA copy, polled timer compare, and OTP readback, then check D-SRAM mailboxes and hardware side effects. |
| OTP programming firmware smoke | Check CPU-controlled OTP programming flow | Load `otp_program_otp.hex`, copy `.fasttext` to I-SRAM, execute the OTP programming routine from I-SRAM, and check the programmed OTP word plus status bits. |
| DMA copy firmware smoke | Check DMA moves real D-SRAM contents | Load `dma_copy_otp.hex`, let CPU seed D-SRAM source/destination windows, start DMA, and check the destination words plus DMA done/error/IRQ status. |
| UART IRQ firmware smoke | Check UART external interrupt through INTC | Load `uart_irq_otp.hex`, enable UART TX-empty IRQ ID 2 in INTC, claim/complete MEIP in the C trap handler, clear the sticky UART IRQ source, and check D-SRAM mailboxes plus IRQ deassertion. |
| UART RX IRQ firmware smoke | Check UART RX-available and RX-overrun through INTC | Load `uart_rx_irq_otp.hex`, wait for firmware ready mailboxes, drive external UART RX frames from the testbench, handle RX-available and RX-overrun IRQ ID 2 in the C trap handler, and check mailboxes plus IRQ deassertion. |
| DMA IRQ firmware smoke | Check INTC machine external interrupt path | Load `dma_irq_otp.hex`, enable DMA IRQ ID 5 in INTC, start DMA, claim/complete MEIP in the C trap handler, and check D-SRAM mailboxes plus IRQ deassertion. |
| GPIO IRQ firmware smoke | Check external GPIO interrupt through INTC | Load `gpio_irq_otp.hex`, arm GPIO bit 0 as a level-high interrupt, drive `gpio_in[0]`, claim/complete GPIO IRQ ID 4 in the C trap handler, and check D-SRAM mailboxes plus IRQ deassertion. |
| Timer IRQ firmware smoke | Check machine timer interrupt entry/return | Load `timer_irq_otp.hex`, program `mtime/mtimecmp`, enable MTIE/MIE, wait for D-SRAM trap mailboxes, and check timer IRQ deassertion. |
| Debug status | Check core debug status is driven | Wait for either running or halted status to become asserted. |
| JTAG debug smoke | Check SoC-level Debug Module access | Bit-bang JTAG to read IDCODE/DTMCS, write `dmcontrol.dmactive`, and read `dmstatus`. |
| Remote-bitbang smoke | Check OpenOCD-facing socket bridge | Build `Vwasp1` remote-bitbang harness and use a Python client to exercise IDCODE/DTMCS/DMI over TCP. |
| OpenOCD smoke | Check external debugger server compatibility | Run OpenOCD remote_bitbang against `Vwasp1` and require TAP, DTM, hart, XLEN, and `misa` discovery. |
| GDB smoke | Check external GDB register access | Connect `riscv64-elf-gdb` through OpenOCD, reset-halt, read GPRs and PC, detach, and exit. |
| Idle peripheral stability | Check inactive peripherals stay benign | Run additional cycles and ensure WDG reset and I2C OE remain deasserted. |

## 3. Coverage Intent

The smoke test intentionally does not duplicate module-level register and data
coverage. It verifies that the full SoC hierarchy elaborates, that reset-time
CPU traffic can traverse the integrated memory path, and that a generated
stage-1 OTP image reaches the UART MMIO path, that a CPU-controlled OTP
programming routine can run from I-SRAM and update the OTP model through its
register interface, that a longer generated OTP image can combine UART, GPIO,
D-SRAM, DMA, timer, and OTP reads in one boot, that a DMA firmware image can
move real D-SRAM contents through the second AHB master path, that DMA
completion can reach the core as a
machine external interrupt through INTC, that a UART TX-empty source can reach
the same machine external interrupt path through INTC, that external UART RX
serial input can trigger RX-available and RX-overrun interrupt handling through
INTC, that GPIO input level interrupts can reach the same path through INTC,
that a timer interrupt firmware image can enter and return from the C trap
handler, that the
SoC JTAG pins reach the integrated Debug Module, and that an external
OpenOCD/GDB process can complete the stage-1 debug smoke.

## 4. Pass Criteria

All lint targets plus `tb_wasp1` bare/software-loaded simulations, the OTP
programming firmware simulation, the long boot firmware simulation,
the DMA copy firmware simulation,
the UART IRQ firmware simulation, the UART RX IRQ firmware simulation,
the DMA IRQ firmware simulation,
the GPIO IRQ firmware simulation, the timer IRQ firmware simulation,
remote-bitbang smoke, OpenOCD smoke, and GDB smoke must pass without `$error`,
`$fatal`, or debugger command failure. The verification report must record the
observed time-sequenced test actions and pass counter.
