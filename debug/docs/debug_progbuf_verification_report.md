# debug_progbuf Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```text
make -C debug lint-progbuf
make -C debug lint-progbuf-ic
make -C debug lint-progbuf-fpga-v7
make -C debug sim-progbuf
make -C debug sim
make -C wasp1 sim-openocd-gdb-smoke RBB_PORT=9830
python3 docs/tools/audit_graffle_diagram.py debug/docs/diagrams/debug_progbuf_block.graffle
```

## 3. Time-Sequenced Action Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-40ns | Apply asynchronous reset and read all four indices | All selected/full-array words are zero | PASS |
| 40ns-90ns | Write one distinct directed value to each index | Four independent words match the model | PASS |
| 90ns-110ns | Assert clear and write to word 2 on the same edge | Clear wins and every word becomes zero | PASS |
| 110ns-1390ns | Run 64 seeded random index/data writes and full-array checks | Every selected and parallel output matches the model | PASS |

## 4. Coverage Summary

```text
tb_debug_progbuf coverage: pass=67 reset=2 write=68 read=268 priority=1 random=64
tb_debug_progbuf PASS
```

Coverage includes all indices, asynchronous reset, synchronous clear,
clear-over-write priority, independent word retention, combinational read
selection, full executor-view comparison, and 64 deterministic-random writes.

The complete debug regression also passes. The external OpenOCD smoke reports
`datacount=2 progbufsize=0` and passes its existing register, step, and hardware
breakpoint checks, confirming that standalone storage did not create a false
Program Buffer execution claim.

## 5. Residual Scope

This report covers storage only. The standalone sequencing leaf is now covered
by `debug_progbuf_exec_verification_report.md`; DMI routing, `progbufsize`
advertisement, postexec dispatch, core execution, architectural exception
integration, and OpenOCD/GDB Program Buffer use remain future integration work.
