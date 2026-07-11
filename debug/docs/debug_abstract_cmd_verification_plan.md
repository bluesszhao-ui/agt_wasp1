# debug_abstract_cmd Verification Plan

## 1. Goals

Verify exact Access Register field decoding, Access Memory sequencing,
downstream sequencing, data0/data1 behavior, OpenOCD/GDB CSR probe and trigger
CSR behavior, cmderr mapping, and transaction aborts independently of DMI and
core.

## 2. Directed Cases

```text
successful GPR read and write
successful local `misa`, `dcsr`, and `dpc` CSR probes
supported `dcsr.step` set/read/clear
two-slot RV32 mcontrol trigger discovery through `tselect`, `tdata1`, `tdata2`, and `tinfo`
independent execute-only, load-only, store-only, and combined load/store output qualification
shared per-slot data compare address and isolation between differently configured slots
WARL filtering for unsupported trigger type/action writes
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
unsupported CSR writes other than `dcsr.step` and trigger CSRs, other CSR addresses, and out-of-range register numbers
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
