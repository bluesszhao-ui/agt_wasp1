# core_lsu Spec

## 1. Purpose

`core_lsu` prepares RV32I load/store memory requests and formats load response
data for the core execute path.

## 2. Functional Requirements

The module must support:

```text
LB, LBU
LH, LHU
LW
SB
SH
SW
```

The effective address is `base_i + imm_i`.

## 3. Request Requirements

For aligned accesses, `req_valid_o` must assert when either `load_i` or
`store_i` is asserted.

`req_write_o` must indicate stores.

`req_size_o` must reflect byte, halfword, or word access size.

Store data must be byte-lane aligned according to `req_addr_o[1:0]`, and
`req_wstrb_o` must select exactly the written byte lanes.

## 4. Load Data Requirements

Load response data is selected from `rsp_rdata_i` according to the low address
bits and size.

Signed loads must sign-extend byte or halfword data. Unsigned loads must
zero-extend byte or halfword data.

Word loads return `rsp_rdata_i` unchanged.

## 5. Fault Requirements

Halfword accesses must be aligned to 2 bytes.

Word accesses must be aligned to 4 bytes.

`misaligned_o` must assert for misaligned accesses. Misaligned accesses must
not issue a memory request.

`fault_o` must assert for either `misaligned_o` or `rsp_err_i`.

## 6. Verification Requirements

Verification must cover all load and store sizes, all byte offsets, signed and
unsigned load extension, store strobes and shifted data, misalignment detection,
response error reporting, and deterministic random checks.
