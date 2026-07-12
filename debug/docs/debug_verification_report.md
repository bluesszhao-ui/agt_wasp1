# debug Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-07-12 |
| Tool | Verilator 5.046 |
| Generic lint | PASS: `make -C debug lint` |
| IC lint | PASS: `make -C debug lint-ic` |
| Virtex-7 lint | PASS: `make -C debug lint-fpga-v7` |
| Simulation | PASS: `make -C debug sim` |
| Top block diagram audit | PASS: `debug/docs/diagrams/debug_block.graffle` |
| Top simulation end | `1536ns` |
| Top self-check milestones | 61 |
| Top simulation log | `debug/logs/tb_debug.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Top-Level Time-Sequenced Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| `0ns-36ns` | Assert reset for three clocks and release | DM outputs, DMI response, and core debug requests are idle | PASS |
| `36ns-56ns` | Read inactive `dmstatus` | version 2 and authenticated fields visible | PASS |
| `56ns-186ns` | Activate DM, request halt, report core halted, then request resume and report running | halt/resume requests drive core and retire; dmstatus halted/resumeack fields match | PASS |
| `186ns-386ns` | Write/read GPR x5/x6 through abstract commands | core GPR request/response fields and data0 match | PASS |
| `386ns-436ns` | Read `dpc` from the core model | data0 reads back the core Debug PC value | PASS |
| `436ns-1146ns` | Program two words plus EBREAK, execute no-transfer postexec, execute GPR-read then postexec, and inject a core execution error | word order, request/response backpressure, deferred data0, busy lifetime, progbufsize=4, and EXCEPTION cmderr match | PASS |
| `1146ns-1356ns` | Write/read `dcsr.step`, resume one step, and re-halt | `core_debug.step_req` asserts only during resume and dmstatus re-halts | PASS |
| `1356ns-1536ns` | Exercise unsupported command, cmderr clear, hart reset event, and havereset acknowledge | NOTSUP/W1C and reset sticky behavior match | PASS |

## 4. Top Functional Coverage Summary

| Coverage item | Count | Result |
| --- | ---: | --- |
| Self-check milestones | 61 | PASS |
| DMI reads | 16 | PASS |
| DMI writes | 27 | PASS |
| Halt transaction | 1 | PASS |
| Resume transaction | 1 | PASS |
| GPR write transaction | 1 | PASS |
| GPR read transaction | 1 | PASS |
| DPC CSR read transaction | 1 | PASS |
| Single-step transaction | 1 | PASS |
| Abstract errors and clear | 2 | PASS |
| Reset/reset-sticky classes | 2 | PASS |
| Postexec integration classes | 3 | PASS |

The editable top block diagram passes:

```text
python3 docs/tools/audit_graffle_diagram.py debug/docs/diagrams/debug_block.graffle
plutil -lint debug/docs/diagrams/debug_block.graffle
```

Leaf-level random/backpressure/error coverage remains recorded in:

```text
debug_dmi_regs_verification_report.md
debug_halt_ctrl_verification_report.md
debug_reg_access_verification_report.md
debug_progbuf_verification_report.md
debug_progbuf_exec_verification_report.md
debug_abstract_cmd_verification_report.md
debug_jtag_dtm_verification_report.md
debug_jtag_verification_report.md
```

## 5. Residual Scope

OpenOCD/GDB end-to-end smoke, including native GDB `stepi` over remote-bitbang,
and two hardware breakpoint `hbreak` locations, is covered by the wasp1
top-level verification report. Precise core-side load/store trigger behavior is
covered by the core datapath verification report. OpenOCD/GDB `rwatch` and
`watch` and Program Buffer execution with `progbufsize=4` are covered by the
wasp1 top-level report. System Bus Access, debug ROM,
architectural CSR side effects beyond debugger probes, and multi-hart behavior
beyond nonexistent-hart reporting remain future work.
