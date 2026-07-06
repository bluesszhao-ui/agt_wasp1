# ahb_otp Spec

## 1. Purpose

`ahb_otp` provides executable OTP storage and software-visible OTP programming
control registers.

## 2. Address Requirements

The lower OTP region must be an executable read-only data window. The upper
register window must expose OTP programming and status registers.

## 3. OTP Semantics

OTP data bits must reset to erased value `1`.

Programming may only change bits from `1` to `0`. Any request that would change
a bit from `0` to `1` must be rejected and leave data unchanged.

Programming must require:

```text
valid unlock key
not locked
valid word address
program enable
start command
```

## 4. Register Requirements

The register set must include:

```text
CTRL
STATUS
ADDR
WDATA
RDATA
KEY
LOCK
```

`STATUS` must expose busy, done, error, and locked state.

## 5. Error Requirements

The module must reject direct writes to the data window, out-of-range accesses,
misaligned accesses, unsupported register sizes, and unknown registers.

## 6. Target Requirements

The module must support IC, Virtex-7 FPGA, and generic simulation targets. The
OTP programming contract must not change across targets.

For simulation bring-up, the module may accept `+WASP1_OTP_HEX=<path>` to
preload the OTP data array with a generated firmware image. This is a
simulation-only convenience and must not change the hardware programming
contract.

## 7. Verification Requirements

Verification must cover erased reads, legal programming, illegal bit raising,
bad key, lock behavior, direct data write rejection, register errors, and
deterministic random programming.
