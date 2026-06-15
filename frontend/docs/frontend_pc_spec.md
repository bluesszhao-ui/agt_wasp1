# frontend_pc Spec

## 1. Purpose

`frontend_pc` owns the instruction frontend PC register and produces the current
PC request address for later fetch/cache logic.

## 2. Functional Requirements

`frontend_pc` must:

```text
load boot_pc_i while reset is active
hold request invalid while reset is active
assert pc_valid_o after reset release unless stall_i is high
advance PC by 4 when pc_valid_o and fetch_ready_i are both high
hold PC when fetch_ready_i is low
hold PC and deassert pc_valid_o when stall_i is high
capture redirect_pc_i when redirect_valid_i is high
give redirect higher priority than sequential advance
allow redirect capture even while stall_i is high
report pc_misaligned_o when pc_o[1:0] is non-zero
```

## 3. Interface Contract

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | Frontend clock. |
| `rst_ni` | input | Active-low asynchronous reset. |
| `boot_pc_i` | input | Reset PC value. |
| `stall_i` | input | Blocks PC request valid and sequential advance. |
| `fetch_ready_i` | input | Downstream fetch/cache accepted current PC. |
| `redirect_valid_i` | input | Redirect request qualifier. |
| `redirect_pc_i` | input | Redirect target captured when valid. |
| `pc_valid_o` | output | Current PC request is valid. |
| `pc_o` | output | Current PC request address. |
| `pc_misaligned_o` | output | Current PC has low address bits set. |

## 4. Reset Requirements

During reset, `pc_o` must reflect `boot_pc_i`, `pc_valid_o` must be low, and
`pc_misaligned_o` must reflect the loaded boot PC low bits.

## 5. Target Requirements

`frontend_pc` is target-neutral and must not change behavior across IC,
Virtex-7 FPGA, or generic simulation targets.
