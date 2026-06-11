# ahb_default_slave Spec

## 1. Purpose

`ahb_default_slave` terminates unmapped AHB-Lite accesses.

## 2. Requirements

Selected NONSEQ/SEQ transfers must return:

```text
HRESP = ERROR
HREADY = 1
HRDATA = 0
```

Unselected, IDLE, and BUSY transfers must return:

```text
HRESP = OKAY
HREADY = 1
HRDATA = 0
```

## 3. Verification Requirements

Verification must cover selected active errors, idle/busy OKAY behavior,
unselected OKAY behavior, reads, writes, supported sizes, and deterministic
random selected/unselected transfers.
