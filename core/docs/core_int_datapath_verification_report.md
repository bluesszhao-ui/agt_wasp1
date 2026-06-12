# core_int_datapath Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```sh
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim-core-int-datapath
make -C core sim
make lint
```

## 3. Time/Cycle Action Table

| Time | Cycle Window | Action | Result |
| --- | --- | --- | --- |
| 0ns-21ns | Reset | Hold reset and check boot PC/no commit | Boot PC and no-commit state matched |
| 25ns-55ns | ADDI/dependency | Execute adjacent ADDI instructions | Immediate writeback and dependency passed |
| 55ns-95ns | Register ALU | Execute ADD/SUB and immediate logical path | Register and immediate ALU commits matched |
| 95ns-125ns | Upper/link | Execute LUI/AUIPC/JAL link writeback | U-immediate, PC-relative, and link commits matched |
| 125ns-138ns | Suppression | x0, illegal, unsupported load, NOP suppressions | All write suppressions matched |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_int_datapath coverage: pass_count=12 commit=8 alu_i=3 alu_r=2 upper=2 link=1 suppress=4 pc=12
tb_core_int_datapath PASS
```

Coverage intent met:

- Immediate ALU writeback.
- Register-register ALU writeback.
- Adjacent dependency through staged regfile timing.
- LUI and AUIPC writeback.
- JAL link writeback.
- x0, illegal, unsupported, and NOP suppression.
- Fetch PC stepping.
