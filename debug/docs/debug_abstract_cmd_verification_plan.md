# debug_abstract_cmd Verification Plan

## 1. Goals

Verify exact Access Register field decoding, downstream sequencing, data0
behavior, minimal OpenOCD/GDB CSR probe behavior, cmderr mapping, and transaction
aborts independently of DMI and core.

## 2. Directed Cases

```text
successful GPR read and write
successful read-only `misa`, `dcsr`, and `dpc` CSR probes
request and response delay
downstream error -> CMDERR_EXCEPTION
hart running at command -> CMDERR_HALT_RESUME
hart leaves halted state in ISSUE and WAIT
DM deactivation in ISSUE and WAIT
transfer=0 successful no-op
unsupported cmdtype
reserved bit 23
unsupported aarsize
aarpostincrement
postexec
unsupported CSR write, other CSR addresses, and out-of-range register numbers
command pulse while busy ignored defensively
reset during active command
```

## 3. Random Coverage

Run deterministic-random valid GPR reads/writes with randomized command
backpressure, response latency, read data, and error injection. Compare every
request and completion against a reference command decoder.

## 4. Target Matrix

Generic, IC, and Virtex-7 lint plus the complete debug simulation aggregate
must pass before commit.
