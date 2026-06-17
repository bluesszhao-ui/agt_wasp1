# frontend_ibuf Spec

## 1. Purpose

`frontend_ibuf` is the small instruction buffer between fetch response
generation and the later core-side instruction consumer. It decouples fetch
response timing from core backpressure while preserving instruction metadata.

## 2. Functional Requirements

`frontend_ibuf` must:

```text
store fetched instruction PC and instruction word
store fetch fault and misaligned-PC metadata
present the oldest queued instruction first
support ready/valid push and pop handshakes
report empty and full status
block pushes while full
block visible pops while empty
support simultaneous push and pop when non-empty and not full
clear all queued instructions on flush_i
suppress push and pop handshakes while flush_i is asserted
```

## 3. Interface Contract

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | Frontend clock for FIFO state. |
| `rst_ni` | input | Active-low asynchronous reset. |
| `flush_i` | input | Clears all queued entries on the next rising clock and suppresses visible handshakes while asserted. |
| `push_valid_i` | input | Fetch response is valid. |
| `push_ready_o` | output | Buffer can accept the fetch response this cycle. |
| `push_pc_i` | input | PC associated with the fetch response. |
| `push_instr_i` | input | Fetched instruction word. |
| `push_fault_i` | input | Fetch response has a fault. |
| `push_misaligned_i` | input | Fetch fault is due to a misaligned PC. |
| `pop_valid_o` | output | Oldest queued instruction is valid. |
| `pop_ready_i` | input | Consumer accepts the oldest queued instruction. |
| `pop_pc_o` | output | PC for the oldest queued instruction. |
| `pop_instr_o` | output | Instruction word for the oldest queued instruction. |
| `pop_fault_o` | output | Fault flag for the oldest queued instruction. |
| `pop_misaligned_o` | output | Misaligned-PC flag for the oldest queued instruction. |
| `empty_o` | output | No valid entries are queued. |
| `full_o` | output | All entries are occupied. |

## 4. Ordering Requirements

The buffer is FIFO ordered. A successful pop must return entries in the same
order as successful pushes, including all metadata bits.

There is no empty-buffer bypass path. If the buffer is empty and push and pop
intent are both asserted, the push is accepted and the entry becomes visible on
the following cycle.

## 5. Target Requirements

`frontend_ibuf` is target-neutral synthesizable SystemVerilog and must lint
without programmer-visible behavior changes for:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
