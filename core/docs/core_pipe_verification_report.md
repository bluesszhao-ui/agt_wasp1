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
| 0ns-21ns | Reset | Hold reset and check invalid slots | Invalid NOP slots matched |
| 25ns-45ns | Fetch/advance | Accept two instructions and advance IF/ID to EX/WB | PC, instruction, and valid movement matched |
| 55ns-75ns | Stall/bubble | Hold IF/ID, block fetch, and bubble EX/WB | Hold and bubble behavior matched |
| 85ns-105ns | Fault | Capture and advance fetch fault metadata | Fault flag propagated through IF/ID and EX/WB |
| 115ns-125ns | Redirect | Flush slots and forward redirect PC | Slots flushed and redirect output matched |
| 135ns-1335ns | Random | 120 deterministic random control cycles | All cycles matched the reference model |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_pipe coverage: pass_count=129 fetch=15 advance=24 stall=39 bubble=20 redirect=57 fault=7 random=120
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
- 120 deterministic random control cycles.
