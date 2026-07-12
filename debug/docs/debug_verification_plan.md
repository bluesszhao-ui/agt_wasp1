# debug Verification Plan

## 1. Scope

This plan covers the `debug` top-level integration of the verified stage-1
Debug Module leaves. Leaf-module exhaustive behavior remains covered by their
own verification plans and reports.

## 2. Directed Integration Cases

| Phase | Action | Expected result |
| --- | --- | --- |
| Reset | Assert `rst_ni=0` for three clocks | DMI response, DM outputs, core requests, and GPR request outputs are idle |
| Identity | Read inactive `dmstatus` | version/authenticated fields are visible |
| Activation | Write `dmcontrol.dmactive` | `dmactive_o=1`; no unintended halt/resume/step |
| Halt | Write halt request, then assert core halted | `core_debug.halt_req` asserts then retires; halted status reads back |
| Resume | Write resume request, then assert core running | `core_debug.resume_req` asserts then retires; resumeack reads back |
| GPR write | Write `data0`, issue Access Register write x5 | GPR request writes x5 with the data0 payload |
| GPR read | Issue Access Register read x6 and return core data | data0 reads back the core response |
| Program Buffer discovery | Read `abstractcs`, write/read `abstractauto` | Four words are advertised; autoexec remains WARL-zero |
| Postexec no transfer | Program two instructions plus EBREAK and issue postexec-only command | Core requests preserve word order and abstract busy lasts through completion |
| Transfer then postexec | Complete GPR read before accepting Program Buffer request | Executor starts only after transfer success and data0 updates after final success |
| Postexec error | Return core execution error | Executor terminates and sticky `cmderr=EXCEPTION` |
| Abstract error | Issue unsupported Access Register size | `abstractcs.cmderr=NOTSUP`, then W1C clear works |
| Reset sticky | Pulse `hart_reset_event_i` and acknowledge it | `dmstatus.havereset` sets and clears through `dmcontrol.ackhavereset` |

## 3. Coverage Intent

The top-level test must cover at least one halt, resume, GPR write/read,
postexec-only command, transfer-plus-postexec command, core execution error,
sticky reset event, DMI read/write transaction, and clean reset behavior.

## 4. Target Matrix

| Target | Command | Expected result |
| --- | --- | --- |
| Generic lint | `make -C debug lint` | PASS |
| IC lint | `make -C debug lint-ic` | PASS |
| Xilinx Virtex-7 lint | `make -C debug lint-fpga-v7` | PASS |
| Functional simulation | `make -C debug sim` | PASS |
