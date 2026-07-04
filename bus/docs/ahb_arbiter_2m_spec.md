# ahb_arbiter_2m Spec

## 1. Purpose

`ahb_arbiter_2m` arbitrates between the core AHB master and DMA AHB master.

## 2. Master Contract

Master request is defined as:

```text
HTRANS[1] = 1
```

The granted master's address/control/write data must be forwarded to the shared
slave side during a non-pipelined single-beat transaction. The shared response
must be routed back only to the transaction owner.

## 3. Arbitration Requirements

Single requesting master must be granted.

When both masters request accepted transfers, grants must alternate between
masters.

The arbiter must not issue a new address phase while the selected transaction
is in WAIT or RESP. If the selected slave keeps `HREADY=0`, the transaction
owner and write data must remain stable.

## 4. Non-Granted Response Requirements

A non-granted requesting master must see `HREADY=0`.

A non-requesting master must see:

```text
HRDATA = 0
HREADY = 1
HRESP = OKAY
```

## 5. Verification Requirements

Verification must cover single-master transfers, simultaneous requests,
round-robin alternation, WAIT/RESP stall hold, write-data hold, response
routing, and error response forwarding.
