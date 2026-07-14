# Linux Host Setup

Linux uses standard components only:

```text
Channel A: OpenOCD ftdi driver through libusb-1.0
Channel B: kernel ftdi_sio VCP driver and /dev/ttyUSBx
```

Install OpenOCD, libusb, Python, and pyserial using the distribution package
manager. Install `99-wasp1-ftdi.rules` into `/etc/udev/rules.d/`, then reload
udev rules or reconnect the debugger. The rule uses `TAG+="uaccess"`; no global
world-writable device permission is granted.

Verify enumeration before connecting a target:

```text
lsusb -d 0403:6010
python3 ../wasp1_otp_tool.py probe
openocd -f ../../openocd/wasp1_ft2232h_reference.cfg
```

If both FT2232H interfaces bind to `ftdi_sio`, OpenOCD normally detaches only
the selected Channel A interface through libusb. A production EEPROM profile
may instead mark Channel A for the direct interface and retain VCP on Channel
B, reducing interface-selection ambiguity.
