# core_pipe Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```sh
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim-core-pipe
make -C core sim
make lint
```

## 3. Time/Cycle Action Table

| Time | Cycle Window | Action | Result |
| --- | --- | --- | --- |
| 0ns-16ns | Reset | Hold reset and check invalid slots/tags | Invalid NOP slots with debug=0 matched |
| 16ns-36ns | Fetch/advance | Accept two frontend instructions and advance IF/ID to EX/WB | PC, instruction, valid, and debug=0 movement matched |
| 36ns-66ns | Stall/bubble/release | Hold IF/ID, block fetch, bubble EX/WB, then release | Hold, bubble, and advance behavior matched |
| 66ns-86ns | Fault | Capture and advance fetch fault metadata | Fault propagated while debug tag remained zero |
| 86ns-96ns | Redirect | Flush slots and forward redirect PC | Slots/tags flushed and redirect output matched |
| 96ns-140ns | Debug injection | Inject while frozen, advance tag, backpressure occupied pipe, collide with redirect | Frontend excluded; tag and all priorities matched |
| 140ns-1346ns | Random | 120 deterministic random control cycles | All cycles matched the reference model |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_pipe coverage: pass_count=133 fetch=15 advance=24 stall=39 bubble=20 redirect=58 fault=7 random=120 debug_inject=1 debug_bp=1 debug_redirect=1
tb_core_pipe PASS
```

Coverage intent met:

- Invalid pipeline slots after reset.
- Instruction stream acceptance and frontend-model PC + 4 stepping.
- IF/ID to EX/WB advance.
- Fetch/decode stall hold.
- Execute bubble insertion.
- Redirect flush and redirect output forwarding.
- Fetch fault propagation.
- Frozen-pipeline debug injection with frontend exclusion.
- Debug source-tag advance and slot-clear behavior.
- Occupied-pipeline debug backpressure.
- Redirect priority over simultaneous debug injection.
- 120 deterministic random control cycles.
