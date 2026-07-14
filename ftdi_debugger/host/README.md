# wasp1 Host Tools

This directory contains user-space host support for the FT2232H debugger. It
does not contain a custom USB kernel driver.

```text
Channel A: OpenOCD ftdi adapter -> libusb -> FT2232H MPSSE JTAG
Channel B: wasp1-otp -> operating-system serial API -> FTDI VCP UART
```

## OTP Tool

Install the optional serial dependency:

```text
python3 -m pip install -r ftdi_debugger/host/requirements.txt
```

Probe a loader, inspect status, and read bytes:

```text
python3 ftdi_debugger/host/wasp1_otp_tool.py --port /dev/ttyUSB1 probe
python3 ftdi_debugger/host/wasp1_otp_tool.py --port /dev/ttyUSB1 status
python3 ftdi_debugger/host/wasp1_otp_tool.py --port /dev/ttyUSB1 read \
  --offset 0x0 --length 256 --output otp.bin
```

Programming and permanent locking require explicit confirmation flags:

```text
python3 ftdi_debugger/host/wasp1_otp_tool.py --port /dev/ttyUSB1 program \
  firmware.bin --offset 0x0 --yes-program
python3 ftdi_debugger/host/wasp1_otp_tool.py --port /dev/ttyUSB1 lock \
  --yes-lock
```

Programming performs a complete pre-read, rejects every attempted `0 -> 1`
transition locally, programs in bounded chunks, and verifies by default.

The target must already be running a loader that implements the protocol in
`../docs/ftdi_debugger_host_software_spec.md`. A blank device can reach this
state by loading the target-side programmer into I-SRAM through JTAG; a later
production image may contain a protected resident loader.

## Verification

```text
make -C ftdi_debugger host-test
make -C ftdi_debugger host-lint
```

Platform setup is documented under `linux/` and `windows/`.
