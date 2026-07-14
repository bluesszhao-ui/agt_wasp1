# FT2232H EEPROM Provisioning

Rev A can fit the optional 93LC56B EEPROM. Initial unpopulated-board bring-up
uses the FT2232H defaults. Production provisioning should define and archive:

```text
assigned VID/PID
manufacturer and product strings
unique per-board serial number
Channel A direct/libusb-oriented mode for OpenOCD
Channel B VCP mode for UART
maximum USB current matching the final board declaration
```

Use FT_PROG or an audited equivalent to read, program, and read back the EEPROM.
Never clone one serial number across manufactured boards. The exported FT_PROG
template and its checksum belong here after the project USB identity and final
power declaration are frozen.
