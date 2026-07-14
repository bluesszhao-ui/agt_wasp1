# ftdi_debugger Host Verification Report

## 1. Scope

This report covers host-side protocol/client tests, target C model tests, RV32I
I-SRAM loader build, and complete-SoC UART/OTP simulation. It does not claim
USB electrical, physical OTP macro, or Windows signed-INF verification.

## 2. Commands

```text
make -C ftdi_debugger host-lint
make -C ftdi_debugger host-test
make -C llvm_s1 uart-otp-protocol-test uart-otp-loader
make -C wasp1 sim-uart-otp-loader
```

## 3. Time-Sequenced Results

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ms-10ms | Encode/decode valid request and response | all fields round-trip | PASS |
| 10ms-20ms | Corrupt CRC; truncate and oversize frames | malformed frames rejected | PASS |
| 20ms-30ms | Probe model loader | geometry and capabilities match | PASS |
| 30ms-40ms | Read across 8-byte chunk boundary | request sizes are 8, 8, 4 | PASS |
| 40ms-50ms | Pre-read, program 12 bytes, verify | writes are 8 and 4 bytes; image matches | PASS |
| 50ms-60ms | Request one illegal `0 -> 1` bit | client rejects before PROGRAM | PASS |
| 60ms-70ms | Exercise unaligned and out-of-range requests | local safety checks reject requests | PASS |
| 70ms-80ms | Return LOCKED and wrong sequence | contextual protocol errors raised | PASS |
| 80ms-90ms | Lock model and inspect status | status lock bit 3 is set | PASS |
| 90ms-100ms | Compile target protocol against native OTP model | CRC, whole-frame precheck, errors, lock, and status pass | PASS |
| 100ms-110ms | Build freestanding RV32I image at I-SRAM base | 2320-byte ELF/bin links without libc | PASS |
| 0us-862us simulated | Run OTP trampoline, I-SRAM loader, 8N1 protocol, and real OTP registers | 15 end-to-end checks pass | PASS |
| offline network check | Download and install pinned pyserial in ignored local target | pyserial 3.5 imports and OTP CLI starts | PASS |

## 4. Coverage Summary

```text
frame fields and little-endian encoding
CRC32 corruption detection
short and oversized frame rejection
HELLO geometry/capability parsing
bounded READ and PROGRAM chunking
complete destination pre-read
0 -> 1 rejection before irreversible command
word-alignment and OTP-range checks
target error propagation
response sequence matching
program readback verification
permanent-lock capability and status path
Windows/Linux FT2232H Channel B enumeration and ambiguity rejection
native C target protocol model and known CRC vector
freestanding RV32I + Zicsr I-SRAM image
bit-serial SoC UART receive and firmware UART transmit path
real OTP ADDR/RDATA, KEY, WDATA, CTRL, STATUS, and LOCK operation
stale D-cache avoidance through uncached OTP_RDATA
```

## 5. Residual Risk

```text
physical FT2232H Channel B testing
Windows Interface A WinUSB binding and Interface B VCP coexistence
Linux udev behavior on supported distributions
disconnect/retry behavior against a real loader
real OTP macro program timing, voltage, and power-failure behavior
production USB identity and signed Windows INF package
```
