# common Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-10 |
| Tool | Verilator 5.046 |
| Command | `make -C common lint` |
| Result | PASS |
| Log | `common/logs/lint.log` |

## 2. Time-Sequenced Case Table

The lint run is not a timed RTL simulation, so the time ranges below describe
the intended lint phases in sequence.

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-1ns | Parse `wasp1_pkg.sv` | Global parameters and typedefs compile | PASS |
| 1ns-2ns | Parse interfaces | AHB, memory, IRQ, and debug interfaces compile | PASS |
| 2ns-3ns | Parse reset/sync helpers | Sequential helper modules compile | PASS |
| 3ns-4ns | Parse FIFO/skid buffer | Ready/valid helper modules compile | PASS |
| 4ns-5ns | Elaborate `common_lint_top` | Common files connect in one lint context | PASS |

## 3. Notes

The first lint pass found that `TRAP_CAUSE_ECALL_MMODE` and
`TRAP_CAUSE_M_EXTERNAL_IRQ` share the same low cause code. This is legal in
RISC-V because interrupt causes are distinguished by the interrupt bit in
`mcause`, but it is not legal as overlapping enum values. The cause definitions
were changed to localparams.

`UNUSEDPARAM` warnings are disabled for the lint target because `wasp1_pkg`
intentionally defines global constants before all consumers exist.
