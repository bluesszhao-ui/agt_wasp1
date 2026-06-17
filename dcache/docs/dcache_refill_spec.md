# dcache_refill Spec

## 1. Purpose

`dcache_refill` sequences a full cache-line refill for a D-cache load miss. It
issues one downstream 32-bit data read per cache-line word and assembles the
completed line for tag/data update.

## 2. Functional Requirements

`dcache_refill` must:

```text
accept one start request while idle
align start_addr_i down to the cache-line base
issue one downstream word read for each word in the cache line
mark downstream requests as data accesses with req_instr=0
assemble response words little-endian by beat number
accumulate any downstream response error into line_error_o
hold completed line outputs stable until line_ready_i
support downstream request backpressure
support downstream response wait states
support completed-line backpressure
abort active refill on flush_i without producing line_valid_o
```

## 3. Interface Contract

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | Refill FSM clock. |
| `rst_ni` | input | Active-low asynchronous reset. |
| `flush_i` | input | Abort active refill and suppress completion. |
| `start_valid_i` | input | New load-miss refill request valid. |
| `start_ready_o` | output | Refill can accept a start request. |
| `start_addr_i` | input | Miss address; low line offset bits are cleared internally. |
| `line_valid_o` | output | Completed cache line is available. |
| `line_ready_i` | input | Cache accepted the completed line. |
| `line_addr_o` | output | Line-aligned refill address. |
| `line_data_o` | output | Assembled line data. |
| `line_error_o` | output | At least one refill beat had `mem_if.rsp_err`. |
| `mem_if` | initiator | Downstream data memory request/response interface. |

## 4. Downstream Request Contract

Each refill beat must drive:

```text
req_write = 0
req_size  = 2
req_wdata = 0
req_wstrb = 0
req_instr = 0
```

`req_addr` is the line base plus `beat * 4`.

## 5. Target Requirements

The block is functionally target-neutral and has no target-specific storage
attributes.
