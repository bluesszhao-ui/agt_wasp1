# Windows Host Setup

The reference Windows arrangement uses two standard per-interface drivers:

```text
FT2232H Interface A: WinUSB for OpenOCD/libusb MPSSE JTAG
FT2232H Interface B: FTDI VCP for the COM-port UART
```

1. Install a current OpenOCD build and the official FTDI VCP package.
2. In Device Manager, confirm that Channel B appears as a COM port.
3. Bind only FT2232H Interface A to WinUSB. Zadig is suitable for development.
4. Do not replace the driver for the whole composite device or Interface B.
5. Run OpenOCD with `ftdi_debugger/openocd/wasp1_ft2232h_reference.cfg`.
6. Run `wasp1_otp_tool.py --port COM<number> probe` against Channel B.

For distribution, replace the manual Interface A binding with a signed INF
package that selects WinUSB for the project VID/PID and interface number. Such
an INF is installation metadata for the standard WinUSB driver, not a custom
wasp1 kernel driver.

The default FTDI `0403:6010` identity is acceptable for internal bring-up. A
released product must use a properly assigned/licensed USB identity and update
the OpenOCD config, udev rule, INF package, and EEPROM profile together.
