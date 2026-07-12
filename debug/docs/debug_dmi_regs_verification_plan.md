# debug_dmi_regs Verification Plan

## 1. Scope

Verify the DMI register bank, one-entry response transport, control/status
semantics, abstract payload protection, and four-word Program Buffer routing.

## 2. Program Buffer Cases

| Case | Stimulus | Expected result |
| --- | --- | --- |
| Reset image | Read all four words after reset | Every word and full-array output are zero |
| Directed access | Write a unique instruction to each address | Each read and exported word matches independently |
| Busy write | Write each word while `abstract_busy_i=1` | Payload is preserved and `cmderr=BUSY` |
| Busy read | Read a Program Buffer/data word while busy | Data returns, sticky `cmderr=BUSY` is set |
| Random access | Seeded random address/data writes and reads | DMI and full-array views match a software model |
| DMI backpressure | Hold every response for one cycle | Response and Program Buffer state remain stable |
| dmactive clear | Clear `dmactive` after filling all words | All words clear and inactive writes have no effect |

## 3. Existing Regression Cases

Retain activation, hart selection/status, halt/resume priority, sticky reset,
data0/data1 ownership, command pulse, W1C cmderr, illegal DMI operation/address,
zero-bubble response replacement, and deterministic-random data coverage.

## 4. Target Matrix

Run `make -C debug lint-dmi-regs`, `lint-dmi-regs-ic`,
`lint-dmi-regs-fpga-v7`, and `sim-dmi-regs`, followed by complete debug and root
lint regressions.
