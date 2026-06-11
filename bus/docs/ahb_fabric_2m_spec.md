# ahb_fabric_2m Spec

## 1. Purpose

`ahb_fabric_2m` integrates arbitration, address decode, response muxing, and the
default slave into one two-master AHB-Lite fabric.

## 2. Requirements

The fabric must expose:

```text
two master-side AHB-Lite ports
external slave-side AHB-Lite signals
grant visibility
default select visibility
slave select error visibility
```

The fabric must route the selected master's transfer to the decoded external
slave or default slave, and route the selected slave response back to the
granted master.

## 3. Error Requirements

Unmapped addresses must use the default slave and return ERROR for active
transfers.

Illegal slave response selection must assert `slave_select_err_o`.

## 4. Verification Requirements

Verification must cover m0 and m1 routing, default errors, stall propagation,
round-robin arbitration through the integrated fabric, and idle behavior.
