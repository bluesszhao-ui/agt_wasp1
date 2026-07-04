# wasp1 OTP Boot Strategy

## 1. OTP Role

OTP is the primary non-volatile executable program storage for wasp1. The reset
vector points to OTP.

```text
OTP_BASE = 0x0000_0000
```

## 2. OTP Behavior

The RTL OTP model is SRAM-based but enforces typical OTP semantics:

```text
default bit value is 1
program operation can only change 1 to 0
program operation cannot change 0 to 1
lock prevents further programming
programming exposes busy, done, and error status
```

## 3. Programming Model

The CPU programs OTP through memory-mapped OTP control registers.

UART is used only as a communication channel. The UART programming protocol is
software running on the CPU, not hardwired UART-to-OTP logic.

## 4. Safety Rule

OTP programming routines must execute from I-SRAM.

This avoids programming the same OTP array that is simultaneously used for
instruction fetch.

The current directed firmware regression enforces this rule with
`llvm_s1/bsp/examples/otp_program.c`: startup copies the `.fasttext` routine to
I-SRAM, the routine writes the OTP programming registers, and the top-level
testbench checks OTP word address `0x00003fa0` for data `0x13572468` with
`done=1` and `error=0`.

## 5. Boot Flow

```text
reset
  -> PC = OTP_BASE
  -> execute startup code from OTP
  -> optionally copy .fasttext to I-SRAM
  -> copy .data from OTP to D-SRAM
  -> clear .bss in D-SRAM
  -> call main
```

## 6. OTP Registers

Initial register set:

| Register | Purpose |
| --- | --- |
| `OTP_CTRL` | Program enable, start command |
| `OTP_STATUS` | Busy, done, error, locked |
| `OTP_ADDR` | Word address |
| `OTP_WDATA` | Program data |
| `OTP_RDATA` | Read data |
| `OTP_KEY` | Programming unlock key |
| `OTP_LOCK` | Permanent or model-level lock control |
