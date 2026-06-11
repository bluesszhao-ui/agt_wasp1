# core_alu Verification Plan

## 1. Goals

Verify `core_alu` as the RV32I integer ALU execution primitive.

## 2. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Directed | ADD small and wraparound operands | Result matches 32-bit addition | PASS |
| Directed | SUB underflow and edge operands | Result matches 32-bit subtraction | PASS |
| Directed | SLL with shamt 31 and masked shamt | Result uses `rhs[4:0]` | PASS |
| Directed | SLT signed positive/negative cases | Signed compare result correct | PASS |
| Directed | SLTU unsigned high/low cases | Unsigned compare result correct | PASS |
| Directed | XOR/OR/AND pattern operands | Bitwise result correct | PASS |
| Directed | SRL/SRA positive and negative operands | Logical and arithmetic shifts differ correctly | PASS |
| Random | 200 deterministic random op/operand checks | Result matches reference model | PASS |
| Directed | Invalid op encoding | Result is zero | PASS |

## 3. Target Compile Matrix

| Target | Macro | Command | Expected result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C core lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C core lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C core lint-fpga-v7` | PASS |

## 4. Coverage Intent

```text
all ALU operations
wraparound arithmetic
signed compare
unsigned compare
shift amount masking
arithmetic right shift sign extension
invalid op default
deterministic random reference-model checks
```
