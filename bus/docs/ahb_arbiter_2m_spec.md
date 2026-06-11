# ahb_arbiter_2m Spec

## 1. Purpose

`ahb_arbiter_2m` arbitrates between the core AHB master and DMA AHB master.

## 2. Master Contract

Master request is defined as:

```text
HTRANS[1] = 1
```

The granted master's address/control/write data must be forwarded to the shared
slave side. The shared response must be routed back only to the granted master.

## 3. Arbitration Requirements

Single requesting master must be granted.

When both masters request accepted transfers, grants must alternate between
masters.

The current grant must be held while the selected slave keeps `HREADY=0`.

## 4. Non-Granted Response Requirements

A non-granted requesting master must see `HREADY=0`.

A non-requesting master must see:

```text
HRDATA = 0
HREADY = 1
HRESP = OKAY
```

## 5. Verification Requirements

Verification must cover single-master grants, simultaneous requests,
round-robin alternation, stall hold, response routing, and error response
forwarding.
