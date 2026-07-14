# wasp1 UART OTP Loader

## 1. Objective

The loader is a freestanding RV32I + Zicsr program that receives the versioned
OTP protocol through the wasp1 UART and performs irreversible writes only after
the complete request has passed framing, CRC, range, alignment, lock, and
monotonic-bit checks.

It is linked at `0x1000_0000` and must execute from I-SRAM. Manufacturing flow
loads its ELF through JTAG. A future resident recovery flow may copy the same
logic from a protected OTP prefix, but no production partition is assumed yet.

## 2. Software Partition

```text
isram_loader_start.S
  software control: initialize gp/sp/mtvec, clear BSS, call main
    |
    v
uart_otp_loader.c
  software policy: UART framing loop and hardware callback binding
    |
    +--> wasp1_uart_otp_protocol.c
    |      protocol: parse, CRC, validate, dispatch, respond
    |
    +--> UART MMIO at 0x4004_0000
    |
    +--> OTP register MMIO at OTP_REG_BASE
           ADDR/RDATA, KEY, WDATA, CTRL, STATUS, LOCK
```

All hardware-visible accesses are ordered volatile MMIO operations from the
core's single execution stream.

## 3. Memory Layout

| Region | Address | Contents |
| --- | --- | --- |
| `.text/.rodata/.data` | `0x1000_0000` onward | startup, protocol, loader, immutable operation table |
| `.bss` | next aligned I-SRAM address | 276-byte request and response buffers |
| stack | after BSS | 4 KiB loader stack |

The production build is 2320 bytes before zero-filled BSS and stack. The linker
rejects overflow beyond the 64 KiB I-SRAM window; the build script also checks
the flat binary against a 60 KiB code/data budget.

## 4. OTP Access Policy

READ and PROGRAM precheck use `OTP_ADDR` followed by `OTP_RDATA`. They do not
load the executable OTP data window directly. This is required because a direct
load can populate D-cache before programming and return stale data afterward.

One programmed word follows this sequence:

```text
read STATUS and reject LOCK
write CTRL.CLEAR
write KEY = 0x57504f54
write ADDR = word index
write WDATA = requested word
write CTRL = PROG_EN | START
poll STATUS.BUSY until clear
require STATUS.DONE and !STATUS.ERROR
read OTP_RDATA and require exact programmed value
write KEY = 0 to revoke the transient unlock
```

The protocol core validates every word in one PROGRAM frame before calling the
first `program_word` callback. Consequently, an illegal later word cannot leave
an earlier word partially programmed.

## 5. Build Outputs

```text
make -C llvm_s1 uart-otp-loader

llvm_s1/build/uart_otp_loader/wasp1_uart_otp_loader.elf
llvm_s1/build/uart_otp_loader/wasp1_uart_otp_loader.bin
llvm_s1/build/uart_otp_loader/wasp1_uart_otp_loader_isram.hex
```

The default build uses UART divisor 868 for 115200 baud at 100 MHz. The SoC
regression generates a separate ignored build with divisor 4 to keep bit-level
simulation short; protocol and executable code are otherwise identical.

## 6. Verification

`make -C llvm_s1 uart-otp-protocol-test` runs the target protocol against a C
OTP model. `make -C wasp1 sim-uart-otp-loader` then executes the linked RV32I
image in the complete SoC and drives real 8N1 request bits through `uart_rx_i`.

| Simulation time | Action | Result |
| --- | --- | --- |
| 0us-5us | Reset; OTP trampoline jumps to I-SRAM; loader initializes UART | PASS |
| 5us-130us | Send HELLO and validate CRC-protected geometry response | PASS |
| 130us-270us | Program `0x12345678`; inspect physical OTP model | PASS |
| 270us-370us | READ through ADDR/RDATA and compare payload | PASS |
| 370us-500us | Attempt illegal `0 -> 1`; require no storage change | PASS |
| 500us-630us | Corrupt request CRC; require no storage change | PASS |
| 630us-730us | Issue permanent LOCK and read STATUS lock bit | PASS |
| 730us-862us | Attempt post-lock PROGRAM; require LOCKED and no change | PASS |

Physical OTP voltage/timing, cable interruption, power-failure behavior, and
real FT2232H UART operation remain board-level verification items.
