# core_decode Verification Plan

## 1. Strategy

`tb_core_decode` is a self-checking SystemVerilog testbench. It constructs
instructions with local encoder functions and checks decoded outputs against
expected values.

## 2. Planned Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| R-type ALU | Decode all RV32I register-register ALU operations | Correct ALU op and register-use controls |
| I-type ALU | Decode all RV32I register-immediate ALU operations | Correct ALU op, immediate, and register-use controls |
| Branch | Decode BEQ/BNE/BLT/BGE/BLTU/BGEU | Correct branch op and B immediate |
| Load | Decode LB/LH/LW/LBU/LHU | Correct size, sign policy, and I immediate |
| Store | Decode SB/SH/SW | Correct size and S immediate |
| Jump/U-type | Decode LUI/AUIPC/JAL/JALR | Correct flags and immediates |
| CSR | Decode CSRRW/CSRRS/CSRRC/CSRRWI/CSRRSI/CSRRCI | Correct CSR command and address |
| System | Decode ECALL/EBREAK/MRET | Correct system flag |
| Illegal | Decode representative invalid encodings | `illegal_o` asserted |

## 3. Coverage Goals

The bench must hit at least 10 R-type ALU cases, 9 I-type ALU cases, 6 branch
cases, 5 load cases, 3 store cases, 4 jump/U-type cases, 6 CSR cases, 3 system
cases, and 6 illegal cases.
