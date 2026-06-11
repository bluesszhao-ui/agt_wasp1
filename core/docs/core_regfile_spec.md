# core_regfile Spec

## 1. Purpose

`core_regfile` implements the RV32I integer register file for the core.

## 2. Architectural Requirements

The register file must provide 32 logical registers `x0` through `x31`.

`x0` must always read as zero. Writes to `x0` must be ignored.

Registers `x1` through `x31` are 32-bit read/write registers.

## 3. Interface Requirements

Inputs:

```text
clk_i
rst_ni
raddr1_i
raddr2_i
we_i
waddr_i
wdata_i
```

Outputs:

```text
rdata1_o
rdata2_o
```

The module has two independent read ports and one write port.

## 4. Timing Requirements

Writes commit on the rising edge of `clk_i`.

Reads are combinational.

If a read port and the write port address the same nonzero register in the
same cycle while `we_i` is asserted, the read port must return `wdata_i`.

## 5. Reset Requirements

When `rst_ni` is asserted low, all implemented registers `x1` through `x31`
must reset to zero.

## 6. Verification Requirements

Verification must cover reset state, writes to low and high registers, dual
read behavior, ignored writes to `x0`, same-cycle write/read bypass, and
deterministic random register access.
