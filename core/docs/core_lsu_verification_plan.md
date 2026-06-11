# core_lsu Verification Plan

## 1. Strategy

`tb_core_lsu` is a self-checking SystemVerilog testbench with reference
functions for store strobes, shifted write data, load extension, and alignment.

The testbench uses 1ns combinational settle steps because `core_lsu` has no
clocked state.

## 2. Planned Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Idle | No load/store requested | No request and no fault |
| Byte loads | Check offsets 0-3 | Correct byte select and sign/zero extension |
| Half loads | Check low/high halves | Correct half select and sign/zero extension |
| Word load | Check word pass-through | Response data unchanged |
| Byte stores | Check offsets 0-3 | Correct shifted data and single byte strobe |
| Half stores | Check low/high halves | Correct shifted data and two byte strobes |
| Word store | Check full word | Full strobe and unchanged data |
| Misalignment | Check invalid half/word offsets | No request and `misaligned_o` asserted |
| Response error | Drive `rsp_err_i` | `fault_o` asserted |
| Random | Deterministic random load/store checks | RTL matches reference model |

## 3. Coverage Goals

The bench must cover at least 10 load cases, 9 store cases, 4 misaligned cases,
6 sign/zero-extension cases, 100 random cases, and 1 response error case.
