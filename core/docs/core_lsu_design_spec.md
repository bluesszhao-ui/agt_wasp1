# core_lsu Design Spec

## 1. Scope

`core_lsu` is a combinational load/store helper. It does not own memory
handshake state.

## 2. Editable Block Diagram

```text
editable source: core/docs/diagrams/core_lsu_block.graffle
preview export:  none
detail level:    L2
clock domains:   none; pure combinational logic
```

The diagram separates execute-stage address inputs, effective-address and
alignment logic, memory request encoding, store-lane generation, memory response
load-data selection, fault muxing, and LSU output interfaces. Memory handshake
state is owned by pipeline/cache integration, not by this module.

## 3. Design

The module computes:

```text
addr = base_i + imm_i
```

Misaligned halfword accesses are detected with `addr[0]`.

Misaligned word accesses are detected with `addr[1:0] != 0`.

Store byte lanes are generated from `addr[1:0]`. Store data is shifted into the
selected byte lanes before being sent downstream.

Load data is selected from `rsp_rdata_i` using `addr[1:0]` and extended
according to `unsigned_i`.

## 4. Integration Note

Later pipeline integration should connect:

```text
req_valid_o -> mem_req_rsp_if.req_valid
req_addr_o  -> mem_req_rsp_if.req_addr
req_write_o -> mem_req_rsp_if.req_write
req_size_o  -> mem_req_rsp_if.req_size
req_wdata_o -> mem_req_rsp_if.req_wdata
req_wstrb_o -> mem_req_rsp_if.req_wstrb
```

## 5. Target Support

The module is target-neutral combinational logic. No IC or FPGA-specific
primitive is required.
