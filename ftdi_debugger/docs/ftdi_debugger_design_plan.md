# ftdi_debugger Design Plan

## 1. Partition

```text
USB-C / USB-B connector
  -> ESD and power protection
  -> FT2232H
     -> Channel A MPSSE JTAG
     -> Channel B UART
  -> target-voltage sensing and level shifters
  -> wasp1 target connector
```

## 2. Design Steps

| Step | Work Item | Output |
| ---: | --- | --- |
| 1 | Freeze connector pinout and voltage range | pinout table and schematic constraints |
| 2 | Choose FT2232H power/clock/EEPROM circuit | schematic page |
| 3 | Define JTAG/UART level shifting | schematic page and timing/voltage notes |
| 4 | Write OpenOCD FTDI config for the final pin mapping | checked-in `.cfg` |
| 5 | Build PCB | schematic, layout, BOM, assembly notes |
| 6 | Electrical bring-up | USB enumeration and voltage checks |
| 7 | JTAG bring-up | OpenOCD IDCODE/DTM/hart detection on FPGA |
| 8 | GDB bring-up | register read, halt/resume, step/breakpoint milestones |

## 3. Design Notes

Use FT2232H rather than FT232H as the default because the second channel can be
used as a UART. That keeps the final wasp1 development setup simple:

```text
one USB cable -> JTAG debug + UART console / OTP programming
```

Target VREF must define the IO level seen by the target. The debugger should
not drive JTAG or UART pins when VREF is absent.

## 4. Relationship To Current Simulation

The current Verilator remote-bitbang flow proves the chip-side JTAG/DTM/DM
contract before hardware exists:

```text
current: OpenOCD -> remote_bitbang TCP -> Vwasp1 JTAG pins
final:   OpenOCD -> FT2232H MPSSE -> real wasp1 JTAG pins
```

The OpenOCD target section should remain shared between both flows where
practical.

