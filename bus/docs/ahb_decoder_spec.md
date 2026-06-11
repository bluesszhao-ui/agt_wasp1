# ahb_decoder Spec

## 1. Purpose

`ahb_decoder` converts an active AHB address into a one-hot slave select vector.

## 2. Inputs and Outputs

Inputs:

```text
haddr_i
active_i
```

Outputs:

```text
hsel_o
default_sel_o
```

## 3. Requirements

When `active_i=0`, no slave select may be asserted and `default_sel_o` must be
low.

When `active_i=1`, exactly one select bit must be asserted. Mapped addresses
must select their configured slave. Unmapped addresses must select the default
slave and assert `default_sel_o`.

## 4. Verification Requirements

Verification must cover each region base/middle/end address, boundary misses,
inactive behavior, one-hot behavior, and deterministic random unmapped
addresses.
