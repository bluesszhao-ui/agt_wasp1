# tile Verification Report

## 1. Result

The integrated `tile` passes lint for generic simulation, IC, and Xilinx
Virtex-7 targets and passes the self-checking end-to-end simulation.

```text
tb_tile coverage: pass=22 commit=16 redirect=10 hazard=2
imem_req=71 dmem_read=17 dmem_write=1 ibp=9 dbp=6
invalidate=2 fault=1 fetch_fault=1 irq=2 flush=2
tb_tile: PASS
```

The test clock is 10ns (100MHz), with `timescale 1ns/1ps`.

## 2. Verification Configuration

The testbench instantiates the real `frontend`, `icache`, `core`, and `dcache`
through `tile`. Independent instruction and data memory models provide:

```text
one outstanding request per port
deterministic request-ready backpressure
configurable response latency
one-shot instruction refill error injection
data refill error injection
byte-lane-aware write-through backing memory
```

No child cache or core interface is bypassed by the testbench.

## 3. Time-Sequenced Actions

Times below are converted from the simulator's 1ps display units to ns.

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-30ns | Hold reset for the main program. | Frontend, core, and both cache controllers start from reset state. | PASS; no transaction or commit escaped reset. |
| 30ns-1096ns | Execute load/dependent-ALU/store/load/branch program, then invalidate I-cache in the resident loop. | First load performs four-beat refill; store writes through and updates hit line; second load hits updated line; branch skips x5=0x55; I-cache invalidate causes four new refill beats. | PASS; x1=0x100, x2=7, x3=8, x4=8, x5=42; D-memory traffic was exactly four reads plus one write before invalidate; skipped value never committed. |
| 1096ns-1130ns | Reset and select repeated-load program. | All child state returns to reset and cache tags are invalid. | PASS. |
| 1130ns-2126ns | Establish D-cache line, run repeated hits, pulse D-cache invalidate. | Read count remains constant during hits and grows by four refill beats after invalidate. | PASS; no read beat appeared during the pre-invalidate hit window; four appeared after invalidate. |
| 2126ns-2160ns | Reset and enable D-memory error injection. | Clean phase separation. | PASS. |
| 2160ns-2646ns | Return an error on the first D-cache refill beat. | Error remains sticky through refill; core asserts `lsu_fault_o`; x2 writeback is suppressed. | PASS; one LSU fault observed and no x2 commit occurred. |
| 2646ns-2680ns | Reset and arm one-shot I-memory error. | Clean phase separation. | PASS. |
| 2680ns-3106ns | Fault first instruction refill, then allow clean recovery refill. | Faulted x6 instruction does not commit; later x7=7 instruction commits. | PASS; error consumed once, no x6 commit, x7 committed 7. |
| 3106ns-3140ns | Reset and select CSR interrupt-enable program. | Clean phase separation. | PASS. |
| 3140ns-3926ns | Enable MIE/MTIE/MEIE, assert timer IRQ only. | Core reports interrupt cause 7 and redirects to reset `mtvec=0`. | PASS; timer interrupt and redirect observed. |
| 3926ns-3960ns | Reset interrupt program. | Prior trap state is cleared. | PASS. |
| 3960ns-4746ns | Enable interrupts, assert timer and external IRQ together. | External interrupt wins priority with cause 11 and redirects to `mtvec=0`. | PASS; cause 11 observed. |
| 4746ns-4780ns | Reset and increase I-memory latency. | Prepare an active I-cache refill. | PASS. |
| 4780ns-4876ns | Pulse I-cache flush while delayed refill is active. | Active work aborts without commit or trap leakage. | PASS. |
| 4876ns-4910ns | Reset and increase D-memory latency. | Prepare an active D-cache refill. | PASS. |
| 4910ns-5226ns | Pulse D-cache flush while delayed refill is active. | Active load aborts without x2 commit or LSU fault leakage. | PASS. |

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Boot fetch through frontend and I-cache | Covered |
| Instruction miss, refill, and resident hit | Covered |
| Core instruction/redirect handshake | Covered |
| Load miss and four-beat D-cache refill | Covered |
| Load-use pipeline hazard | Covered, 2 cycles |
| Store hit, downstream write-through, cached-data update | Covered |
| Later load hit returns updated store data | Covered |
| I/D downstream request backpressure | Covered, 9/6 cycles |
| Taken branch flushes fall-through | Covered |
| I-cache and D-cache invalidation | Covered, 2 cases |
| I-cache and D-cache active-work flush | Covered, 2 cases |
| Fetch response error and recovery | Covered |
| D-cache refill response error | Covered |
| Timer interrupt propagation | Covered |
| External-over-timer interrupt priority | Covered |
| Illegal/unsupported/MRET unexpected activity | Continuously checked absent |

## 5. Residual Risk

This tile wrapper is structural and adds no independent state. Child-module
random tests remain the primary coverage for cache replacement conflicts,
all byte/halfword store lanes, individual refill error beats, and detailed CSR
legality. Tile integration focuses on cross-module contracts and architectural
end-to-end behavior.

AHB-Lite conversion and instruction/data arbitration are intentionally outside
the tile boundary and require verification at the later SoC integration level.
