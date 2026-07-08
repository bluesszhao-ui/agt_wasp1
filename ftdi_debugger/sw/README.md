# ftdi_debugger Software

This directory is reserved for host-side helper scripts, EEPROM programming
notes, and UART/OTP programming helpers associated with the FTDI debugger.

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
