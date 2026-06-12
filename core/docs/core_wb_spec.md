# core_wb Spec

## 1. Purpose

`core_wb` selects the final integer register writeback value and qualifies the
register-file write enable for the wasp1 core.

## 2. Functional Requirements

The module must select one writeback value from:

```text
ALU result
formatted load data
CSR read data
PC + 4
U-immediate
```

The ALU result is the default source for unknown selector values.

## 3. Write Enable Requirements

The module must assert the final register-file write enable only when all of
the following are true:

```text
writeback slot is valid
decode requested rd write
rd is not x0
no trap is retiring
no late fault is retiring
```

The output write address must mirror `rd_i` even when the write enable is low.

## 4. Interface Requirements

Inputs describe the writeback-stage instruction, destination register, source
selector, trap/fault suppression, and candidate data values.

Outputs drive the integer register file write port.

## 5. Verification Requirements

Verification must cover every source selector, every write suppression cause,
x0 suppression, default selector behavior, and deterministic random checks.
