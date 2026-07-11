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
| 766ns-976ns | Debug halt/single-step/DPC/GPR/resume | Halt after program drain, check captured DPC, single-step one ADDI, re-check DPC, read stepped GPR, read x26, write/read x10, prove x0 stays zero, resume | Halted status, one-instruction step, DPC resume PC, frontend backpressure, GPR responses, and resume matched |
| 976ns-1047ns | Execute trigger breakpoint and resume | Enable trigger at next frontend PC, prove redirect to the same PC, check DPC/cause, clear trigger, resume, and execute the same ADDI normally | Matched instruction did not retire before halt; DPC was match PC; DCSR cause was trigger; post-trigger ADDI committed |
| 1047ns-1167ns | Load trigger precision and isolation | Execute a different-address load, a same-address store, and then an address-matched load; clear the trigger and resume | Address/type isolation passed; the matched load issued no memory request and did not retire or trap; DPC/cause matched; resumed load committed once |
| 1167ns-1287ns | Store trigger precision and isolation | Execute a different-address store, a same-address load, and then an address-matched store; clear the trigger and resume | Address/type isolation passed; the matched store issued no write request and did not retire or trap; DPC/cause matched; resumed store issued exactly once |
| 1287ns-1376ns | Trigger versus misalignment priority | Match a misaligned load address, inspect debug state, clear the trigger, and resume the same instruction | Trigger halted before any request or alignment trap; DPC/cause matched; resumed instruction then raised the expected load-misaligned trap |

## 4. Coverage Summary

The standalone testbench reports:

```text
tb_core_int_datapath coverage: pass_count=93 commit=41 alu_i=15 alu_r=3 upper=2 link=3 branch=2 redirect=9 load=9 store=5 lsu_fault=1 dmem_wait=2 dmem_bp=1 csr=9 trap=5 irq=1 hazard=1 suppress=22 pc=86 debug=17 trigger=4 load_trigger=2 store_trigger=1
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
  x0 debug access, captured DPC resume PC, single-step retirement/re-halt, and
  resume.
- Execute-address trigger halt before matched instruction retirement, DPC at
  the matched PC, DCSR cause=trigger, and normal execution after clearing the
  trigger.
- Exact-address load/store trigger matching with independent type enables and
  unmatched-address/type-isolation checks.
- Precise data-trigger entry before memory request, architectural retirement,
  LSU response fault, or alignment trap, with the EX-stage match PC captured in
  DPC and trigger reported as the DCSR cause.
- Clear-and-resume re-execution of the matched load/store exactly once, plus a
  misaligned-load case proving that the architectural alignment trap occurs
  only after the trigger is cleared.
