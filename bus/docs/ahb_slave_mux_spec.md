# ahb_slave_mux Spec

## 1. Purpose

`ahb_slave_mux` forwards the selected slave response to the granted AHB master.

## 2. Requirements

When no slave is selected:

```text
HRDATA = 0
HREADY = 1
HRESP = OKAY
select_err_o = 0
```

When exactly one slave is selected, that slave's `HRDATA/HREADY/HRESP` must be
forwarded.

When more than one slave is selected, `select_err_o` must assert and `HRESP`
must be ERROR.

## 3. Verification Requirements

Verification must cover no-select, every single slave select, HREADY-low
forwarding, HRESP ERROR forwarding, illegal multi-select, and deterministic
random selects.
