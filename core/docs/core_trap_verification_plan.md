# core_trap Verification Plan

## 1. Strategy

`tb_core_trap` is a self-checking SystemVerilog testbench that drives event
combinations and checks trap metadata plus redirect decisions.

The testbench uses 1ns combinational settle steps because `core_trap` has no
clocked state.

## 2. Planned Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Idle | No trap, MRET, or IRQ | No redirect |
| Synchronous traps | Drive every supported sync trap source | Correct cause, tval, and mtvec redirect |
| MRET | Assert `mret_i` | Redirect to `mepc_i`, no trap write |
| Interrupts | Drive enabled timer/external interrupts | Correct interrupt cause and mtvec redirect |
| Masking | Deassert global or local interrupt enable | No interrupt trap |
| Valid gating | Deassert `valid_i` with events active | No trap or redirect |
| Priority | Combine sync trap, MRET, and IRQ | Required priority is observed |

## 3. Coverage Goals

The bench must cover at least 7 synchronous trap cases, 3 interrupt cases, 1
MRET case, 3 priority cases, and 3 masked/gated cases.
