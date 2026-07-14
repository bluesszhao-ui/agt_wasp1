# ftdi_debugger Host Software Spec

## 1. Purpose

The host package makes the Rev A FT2232H debugger usable on Windows and Linux
without a wasp1-specific kernel driver. Channel A remains a standard OpenOCD
FTDI/libusb path. Channel B remains an FTDI virtual serial port and carries a
versioned wasp1 OTP protocol.

```text
GDB -> OpenOCD -> libusb -> FT2232H Channel A -> JTAG
wasp1-otp -> serial/VCP -> FT2232H Channel B -> wasp1 UART loader
```

## 2. Driver Contract

| Host | Channel A | Channel B | wasp1 kernel driver |
| --- | --- | --- | --- |
| Windows | WinUSB on Interface A for OpenOCD/libusb | official FTDI VCP on Interface B | not required |
| Linux | libusb-1.0 plus udev access | kernel `ftdi_sio` VCP | not required |

Windows installation must bind WinUSB to Interface A only. Replacing the whole
composite device or Interface B would remove the UART COM port. Linux access
must use `TAG+="uaccess"` rather than a world-writable USB or tty node.

## 3. Loader Entry Modes

The UART protocol assumes that compatible target code is already executing
from I-SRAM. Two entry modes are permitted:

| Mode | Use | Loader entry |
| --- | --- | --- |
| Manufacturing/bootstrap | Blank or fully erasable development device | OpenOCD loads the programmer into I-SRAM and starts it through RISC-V debug |
| Resident service | Field-programmable device with a protected OTP prefix | Reset code copies its programmer routine to I-SRAM and enters it under an explicit boot strap/policy |

The manufacturing/bootstrap target loader is implemented under
`llvm_s1/bsp/bootloader/` and links completely into I-SRAM. The project does not
silently reserve an OTP resident-loader partition. That partition, entry strap,
and recovery/security policy must be frozen before a production image uses the
resident-service mode.

## 4. UART Link

```text
baud: 115200 by default
format: 8 data bits, no parity, 1 stop bit
flow control: none
request concurrency: one outstanding frame
integer encoding: little-endian
maximum payload: 256 bytes
```

## 5. Frame Format

CRC32 is the IEEE/zlib CRC over the complete header and payload. The CRC field
itself is excluded.

| Offset | Size | Field | Meaning |
| ---: | ---: | --- | --- |
| 0 | 2 | magic | ASCII `W1`, bytes `0x57 0x31` |
| 2 | 1 | version | protocol version, currently 1 |
| 3 | 1 | kind | 0 request, 1 response |
| 4 | 2 | sequence | wraps modulo 65536; response echoes request |
| 6 | 1 | command | command identifier |
| 7 | 1 | status | zero in requests; response result |
| 8 | 4 | address | byte offset in `OTP_DATA_SIZE` |
| 12 | 2 | payload length | 0 through 256 |
| 14 | 2 | flags | zero until assigned by a later protocol version |
| 16 | N | payload | command-specific data |
| 16+N | 4 | CRC32 | little-endian frame checksum |

The loader must discard bytes until magic is found, reject an unsupported
version or oversized frame, validate CRC before dispatch, and never start an
OTP program pulse for an invalid frame.

Target READ and PROGRAM precheck must use the uncached `OTP_ADDR/OTP_RDATA`
register path. A direct OTP data-window load can leave stale pre-program data in
D-cache and is not valid for post-program verification.

## 6. Commands

| Value | Command | Request | Successful response |
| ---: | --- | --- | --- |
| `0x01` | HELLO | empty | `<otp_data_size:u32, capabilities:u32, max_payload:u16, loader_version:u16>` |
| `0x10` | READ | address plus requested length `u16` | requested OTP bytes |
| `0x11` | PROGRAM | aligned address plus word-aligned bytes | empty after all words complete |
| `0x20` | STATUS | empty | raw OTP STATUS register `u32` |
| `0x21` | LOCK | empty | empty after permanent lock is observed |

Capability bits are READ bit 0, PROGRAM bit 1, and LOCK bit 2. PROGRAM accepts
only a 4-byte-aligned offset and payload length. The loader must validate the
entire request range and all `0 -> 1` violations before issuing the first word
program operation in that frame.

## 7. Status Codes

| Value | Name | Meaning |
| ---: | --- | --- |
| `0x00` | OK | command completed |
| `0x01` | BAD_COMMAND | command is not implemented |
| `0x02` | BAD_VERSION | frame version is unsupported |
| `0x03` | BAD_LENGTH | payload or requested length is invalid |
| `0x04` | BAD_ADDRESS | range exceeds OTP data window |
| `0x05` | BAD_ALIGNMENT | PROGRAM address or length is not word aligned |
| `0x06` | CRC_ERROR | received CRC did not match |
| `0x07` | LOCKED | OTP programming is permanently locked |
| `0x08` | ILLEGAL_TRANSITION | operation attempted a `0 -> 1` transition |
| `0x09` | PROGRAM_ERROR | hardware STATUS reported a program error |
| `0x0a` | BUSY | an operation is already active |
| `0x0b` | INTERNAL_ERROR | loader invariant or unexpected hardware result failed |

## 8. Programming Safety

The host tool must:

```text
require --yes-program before PROGRAM
require --yes-lock before LOCK
probe and enforce OTP_DATA_SIZE
require word alignment for PROGRAM
read the destination before programming
reject every requested 0 -> 1 transition before sending PROGRAM
verify the complete image unless --no-verify is explicitly used
report the first byte offset and values on precheck or verify failure
```

Retries repeat exactly the same sequence and data. Reprogramming a successfully
written word with identical data is idempotent under the OTP AND rule. A target
loader may cache the latest sequence/response to avoid repeating hardware work.

## 9. EEPROM And USB Identity

Default FTDI VID/PID `0403:6010` is an internal bring-up identity. Before
external distribution, the project must obtain a permitted USB identity and
update these as one controlled release:

```text
FT2232H EEPROM image
OpenOCD configuration
Linux udev rule
Windows signed INF package
host auto-detection tests and documentation
```

Every production debugger must have a unique serial number.
