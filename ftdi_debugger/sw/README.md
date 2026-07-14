# ftdi_debugger Software

This directory contains EDA generation and consistency-checking scripts. The
end-user OpenOCD/UART software package is under `../host/`.

The primary OpenOCD configuration lives in:

```text
ftdi_debugger/openocd/wasp1_ft2232h_reference.cfg
```

The baseline plan does not require custom USB firmware.

Stage-1 software expectations:

```text
OpenOCD uses channel A through the standard ftdi adapter driver.
Host serial tooling uses channel B as a standard FTDI UART.
EEPROM programming is optional and limited to product strings, serial numbers,
  and stable channel descriptors.
No private USB protocol is required for debug attach, GDB stepi, hbreak, UART,
  or OTP programming flows.
```

The local consistency checker is:

```text
python3 check_ftdi_debugger_collateral.py
```

The deterministic PCB generator consumes a KiCad XML netlist and system
footprints. `make -C ftdi_debugger kicad-pcb-generate` recreates the four-layer
Rev A placement under `build/` without overwriting the formal routed board.
`kicad-pcb-placement-drc` checks its unrouted-stage DRC contract,
`kicad-pcb-final-drc` checks the committed routed board plus USB length
matching, `kicad-pcb-manufacturing` generates and audits the fabrication and
assembly package, and `kicad-pcb-render` creates a local 3D review image.
