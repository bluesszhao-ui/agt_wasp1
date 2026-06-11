# core_csr Verification Plan

## 1. Strategy

`tb_core_csr` is a self-checking SystemVerilog testbench that drives CSR
commands, trap events, MRET events, interrupt pending inputs, and retire pulses.

The testbench uses the project default 10ns clock period.

## 2. Planned Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Reset | Read implemented writable CSRs after reset | Reset values match spec |
| RW | Write and read `mscratch`, `mstatus`, `mie`, `mtvec`, `mepc` | Old value returned and new value committed |
| RS/RC | Set and clear `mscratch` bits | Bitwise operation is correct |
| Masks | Write all ones to masked CSRs | Only supported bits are retained |
| Read-only | Write `cycle`, `instret`, and `mip` | Illegal asserted |
| Unsupported | Access unsupported CSR address | Illegal asserted |
| IRQ | Drive timer/external IRQ inputs and enable bits | MIP and outputs reflect inputs |
| Counters | Advance clock and retire pulse | `cycle` and `instret` increment |
| Trap | Assert trap event | `mepc/mcause/mtval/mstatus` update |
| MRET | Assert MRET after trap | `MIE` restored from `MPIE` |

## 3. Coverage Goals

The bench must cover at least 6 write/masked-write cases, 2 set/clear cases,
4 illegal/read-only cases, 2 trap/MRET cases, 2 counter cases, and 2 interrupt
enable/pending cases.
