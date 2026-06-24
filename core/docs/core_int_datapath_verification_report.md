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
| 0ns-21ns | Reset | Hold reset and check no commit | No-commit state matched |
| 25ns-55ns | ADDI/dependency | Execute adjacent ADDI instructions | Immediate writeback and dependency passed |
| 55ns-95ns | Register ALU | Execute ADD/SUB and immediate logical path | Register and immediate ALU commits matched |
| 95ns-145ns | Upper/link/redirect | Execute LUI/AUIPC/JAL link and first redirect | U-immediate, PC-relative, link, and redirect matched |
| 145ns-205ns | Suppression and setup | x0, NOP, and branch operands | Suppressions and operand commits matched |
| 205ns-317ns | Branch/JAL/JALR redirect | Taken BEQ, not-taken BEQ, JAL, JALR, redirect bubbles | Targets, links, flushes, and no-write branch behavior matched |
| 317ns-456ns | Load/store/trap/hazard | LW, LB, LBU, SW, SB, misaligned LW, response-error LW, load-use ADD | Load data, store formatting, load trap, response fault, and load-use bubble matched |
| 456ns-496ns | Data response wait | Delayed LW response with request accepted before response valid | Pipeline held until response fire, then load committed |
| 496ns-536ns | Data request backpressure | Hold `dmem_req_ready_i=0` for a load request, then release ready | Request stayed valid, pipeline held, then response committed |
| 536ns-766ns | CSR/trap/IRQ | CSRRW/CSRRS, ECALL, MRET, CSR IRQ enable, timer IRQ | CSR writes, trap metadata, redirects, and interrupt entry matched |
| 766ns-886ns | Debug halt/GPR/resume | Halt after program drain, read x26, write/read x10, prove x0 stays zero, resume | Halted status, frontend backpressure, GPR responses, and resume matched |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_int_datapath coverage: pass_count=74 commit=36 alu_i=13 alu_r=3 upper=2 link=3 branch=2 redirect=8 load=6 store=2 lsu_fault=1 dmem_wait=2 dmem_bp=1 csr=9 trap=4 irq=1 hazard=1 suppress=22 pc=62 debug=7
tb_core_int_datapath PASS
```

Coverage intent met:

- Immediate ALU writeback.
- Register-register ALU writeback.
- Adjacent dependency through staged regfile timing.
- LUI and AUIPC writeback.
- Taken and not-taken branch behavior.
- JAL and JALR link writeback.
- Redirect response blocking, younger-instruction flush, and redirected frontend-model PC.
- LW/LB/LBU load writeback and byte extension.
- SW/SB request address, size, data lane, and strobe formatting.
- Misaligned load trap and response-error LSU fault suppression.
- Valid/ready response wait state with pipeline hold until response fire.
- Request-ready backpressure with request held valid until acceptance.
- CSR old-value writeback, readback, and state update.
- ECALL trap entry, MRET redirect, and timer interrupt trap.
- Load-use stall and execute bubble.
- x0 and NOP suppression.
- Frontend-model PC stepping.
- Debug halt entry, halted frontend backpressure, GPR read, GPR write/readback,
  x0 debug access, and resume.
