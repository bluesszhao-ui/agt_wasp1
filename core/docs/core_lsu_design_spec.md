# core_lsu Design Spec

## 1. Scope

`core_lsu` is a combinational load/store helper. It does not own memory
handshake state.

## 2. Block Diagram

```text
 base_i ----+
 imm_i -----+----> effective address ----+----> req_addr_o
                                      alignment
                                          |
 store_data_i --> lane shifter -----------+----> req_wdata_o
 size_i -------> strobe generator --------+----> req_wstrb_o
 load_i/store_i -------------------------------> req_valid_o/req_write_o

 rsp_rdata_i --> byte/half/word select --> sign/zero extend --> load_data_o
 rsp_err_i ------------------------------+
 misaligned -----------------------------+--------------------> fault_o
```

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
