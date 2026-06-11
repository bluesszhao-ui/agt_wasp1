# core_decode Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```sh
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim
```

## 3. Time/Cycle Action Table

| Time | Cycle Window | Action | Result |
| --- | --- | --- | --- |
| 0ns-10ns | R-type ALU | Decode ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND | PASS |
| 10ns-19ns | I-type ALU | Decode ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI | PASS |
| 19ns-25ns | Branch | Decode all RV32I branch kinds | PASS |
| 25ns-30ns | Load | Decode LB/LH/LW/LBU/LHU | PASS |
| 30ns-33ns | Store | Decode SB/SH/SW | PASS |
| 33ns-37ns | Jump/U-type | Decode LUI/AUIPC/JAL/JALR | PASS |
| 37ns-43ns | CSR | Decode six Zicsr operations | PASS |
| 43ns-46ns | System | Decode ECALL/EBREAK/MRET | PASS |
| 46ns-54ns | Illegal | Decode invalid opcode/funct encodings | PASS |

## 4. Coverage Summary

```text
pass_count=54
alu_r=10
alu_i=9
branch=6
load=5
store=3
jump=4
csr=6
system=3
illegal=8
```

All planned cases passed.
