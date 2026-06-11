# core_regfile Verification Plan

## 1. Strategy

`tb_core_regfile` is a self-checking SystemVerilog testbench with a small
reference model.

The testbench uses the project default 10ns clock period and synchronous write
checks around rising clock edges.

## 2. Planned Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Reset clear | Read every register after reset | All registers read zero |
| x0 immutable | Attempt to write `x0` | `x0` still reads zero |
| Directed writes | Write `x1`, `x2`, and `x31` | Data is retained and readable |
| Dual read | Read two registers at once | Both ports return correct data |
| Same-cycle bypass | Read the register currently being written | Both ports return `wdata_i` |
| Random access | Deterministic random writes and reads | RTL matches reference model |

## 3. Coverage Goals

The bench must cover all 32 logical register addresses, both read ports, the
write port, `x0` write suppression, at least one bypass event, and at least 32
random transactions.
