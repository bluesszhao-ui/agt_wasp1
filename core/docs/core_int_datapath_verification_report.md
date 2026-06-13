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
| 95ns-145ns | Upper/link/redirect | Execute LUI/AUIPC/JAL link and first redirect | U-immediate, PC-relative, link, and redirect matched |
| 145ns-205ns | Suppression and setup | Illegal, unsupported ECALL, x0, NOP, and branch operands | Suppressions and operand commits matched |
| 205ns-317ns | Branch/JAL/JALR redirect | Taken BEQ, not-taken BEQ, JAL, JALR, redirect bubbles | Targets, links, flushes, and no-write branch behavior matched |
| 317ns-407ns | Load/store | LW, LB, LBU, SW, SB, misaligned LW, response-error LW | Load data, store request formatting, and LSU fault handling matched |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_int_datapath coverage: pass_count=38 commit=20 alu_i=10 alu_r=2 upper=2 link=3 branch=2 redirect=4 load=3 store=2 lsu_fault=2 suppress=14 pc=35
tb_core_int_datapath PASS
```

Coverage intent met:

- Immediate ALU writeback.
- Register-register ALU writeback.
- Adjacent dependency through staged regfile timing.
- LUI and AUIPC writeback.
- Taken and not-taken branch behavior.
- JAL and JALR link writeback.
- Redirect response blocking, younger-instruction flush, and redirected PC.
- LW/LB/LBU load writeback and byte extension.
- SW/SB request address, size, data lane, and strobe formatting.
- Misaligned and response-error LSU fault suppression.
- x0, illegal, unsupported, and NOP suppression.
- Fetch PC stepping.
