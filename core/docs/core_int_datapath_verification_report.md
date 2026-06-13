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
| 145ns-205ns | Suppression and setup | x0, NOP, and branch operands | Suppressions and operand commits matched |
| 205ns-317ns | Branch/JAL/JALR redirect | Taken BEQ, not-taken BEQ, JAL, JALR, redirect bubbles | Targets, links, flushes, and no-write branch behavior matched |
| 317ns-407ns | Load/store/trap | LW, LB, LBU, SW, SB, misaligned LW, response-error LW | Load data, store formatting, load misaligned trap, and response fault matched |
| 407ns-546ns | CSR/trap/IRQ | CSRRW/CSRRS, ECALL, MRET, CSR IRQ enable, timer IRQ | CSR writes, trap metadata, redirects, and interrupt entry matched |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_int_datapath coverage: pass_count=59 commit=32 alu_i=13 alu_r=2 upper=2 link=3 branch=2 redirect=8 load=3 store=2 lsu_fault=1 csr=9 trap=4 irq=1 suppress=19 pc=55
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
- Misaligned load trap and response-error LSU fault suppression.
- CSR old-value writeback, readback, and state update.
- ECALL trap entry, MRET redirect, and timer interrupt trap.
- x0 and NOP suppression.
- Fetch PC stepping.
