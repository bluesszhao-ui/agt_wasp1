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
| OTP programming firmware smoke | Check CPU-controlled OTP programming flow | Load `otp_program_otp.hex`, copy `.fasttext` to I-SRAM, execute the OTP programming routine from I-SRAM, and check the programmed OTP word plus status bits. |
| DMA copy firmware smoke | Check DMA moves real D-SRAM contents | Load `dma_copy_otp.hex`, let CPU seed D-SRAM source/destination windows, start DMA, and check the destination words plus DMA done/error/IRQ status. |
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
register interface, that a DMA firmware image can move real D-SRAM contents
through the second AHB master path, that the SoC JTAG pins reach the integrated
Debug Module, and that an external OpenOCD/GDB process can complete the stage-1
debug smoke.

## 4. Pass Criteria

All lint targets plus `tb_wasp1` bare/software-loaded simulations, the OTP
programming firmware simulation, the DMA copy firmware simulation,
remote-bitbang smoke, OpenOCD smoke, and GDB smoke must pass without `$error`,
`$fatal`, or debugger command failure. The verification report must record the
observed time-sequenced test actions and pass counter.
