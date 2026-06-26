# common Design Spec

## 1. Scope

`common` provides shared SystemVerilog packages, interfaces, and small reusable
RTL cells used by wasp1 first-level modules.

It does not implement SoC-visible behavior by itself. Its purpose is to keep
module interfaces consistent and avoid repeated local definitions.

## 2. Editable Block Diagram

```text
editable source: common/docs/diagrams/common_block.graffle
preview export:  none
detail level:    L1
clock domains:   module-local, shown inside each SEQ block
```

`common` is a reusable library, so the diagram is a dependency and ownership
diagram rather than a fixed datapath. It separates package/macro definitions,
SystemVerilog interfaces, sequential helper cells, and first-level module users.

## 3. Files

| File | Purpose |
| --- | --- |
| `wasp1_pkg.sv` | Global parameters, address map, enums, interrupt IDs |
| `ahb_lite_if.sv` | AHB-Lite interface and modports |
| `mem_req_rsp_if.sv` | Lightweight valid/ready memory request-response interface |
| `irq_if.sv` | Interrupt vector interface |
| `debug_if.sv` | Core/debug control interface |
| `reset_sync.sv` | Asynchronous assert, synchronous release reset synchronizer |
| `sync_reg.sv` | Multi-stage signal synchronizer |
| `simple_fifo.sv` | Ready/valid synchronous FIFO |
| `skid_buffer.sv` | One-entry ready/valid skid buffer |

## 4. Interface Policy

AHB-Lite fabric and memory-mapped IP use `ahb_lite_if`.

Core, frontend, I-cache, D-cache, and tile-local arbitration use
`mem_req_rsp_if`.

Interrupt-producing modules expose interrupt bits through `irq_if`.

Core/debug coupling uses `debug_if`; the RISC-V debug module maps this into the
internal core control path. Its modports separate ownership:

```text
dm_ctrl  halt/resume/step requests plus running/halted status
dm_gpr   GPR request/response channel only
dm       complete Debug Module view for final integration
core     complete core-side view
monitor  passive verification view
```

The split DM modports allow `debug_halt_ctrl` and `debug_reg_access` to connect
to the same eventual interface without either submodule driving the other's
signals.

## 5. Synthesis Notes

All RTL in `common/rtl` must be synthesizable. Interfaces are used only for
structural connectivity and must avoid unsynthesizable procedural behavior.

`simple_fifo` and `skid_buffer` are intentionally small and generic. Deep or
clock-crossing FIFOs should be introduced later as dedicated modules if needed.
