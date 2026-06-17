# dcache_store Spec

## 1. Purpose

`dcache_store` is the write-through store sequencer for the D-cache. It accepts
one already-decoded store transaction from the later `dcache_ctrl`, issues one
downstream data write request, waits for the downstream response, and reports
completion.

## 2. External Contract

The module uses one clock/reset domain:

```text
clk_i:  store controller clock
rst_ni: active-low asynchronous reset
```

Input `flush_i` aborts any active store and suppresses request/response outputs.

## 3. Start Interface

`start_valid_i` and `start_ready_o` form the request handshake. When both are
high, the module captures:

```text
start_addr_i:  byte address
start_size_i:  size encoding passed through to the downstream memory path
start_wdata_i: write data
start_wstrb_i: byte strobes
```

The sequencer does not reinterpret alignment, size, or strobe legality. The
later D-cache control path and LSU are responsible for formatting legal stores.
This leaf passes the captured fields through exactly.

## 4. Downstream Memory Behavior

For each accepted start, `dcache_store` emits exactly one downstream request:

```text
mem_if.req_valid = 1 while waiting for req_ready
mem_if.req_write = 1
mem_if.req_instr = 0
mem_if.req_addr  = captured address
mem_if.req_size  = captured size
mem_if.req_wdata = captured write data
mem_if.req_wstrb = captured byte strobes
```

After the request is accepted, the module asserts `mem_if.rsp_ready` while
waiting for one response. `mem_if.rsp_err` is captured as the store completion
error. `mem_if.rsp_rdata` is ignored for writes.

## 5. Completion Interface

`done_valid_o` and `done_ready_i` form the completion handshake. While
`done_valid_o` is high, the completion payload remains stable:

```text
done_addr_o
done_size_o
done_wdata_o
done_wstrb_o
done_error_o
```

The later control FSM can use the payload to update `dcache_data` on a store hit
only after a successful downstream write.

## 6. Target Requirements

The module is target-neutral synthesizable logic and must behave identically for:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
