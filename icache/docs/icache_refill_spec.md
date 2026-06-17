# icache_refill Spec

## 1. Purpose

`icache_refill` sequences a direct-mapped instruction-cache line refill from a
downstream word-oriented memory path.

## 2. Functional Requirements

`icache_refill` must:

```text
accept a refill start request only while idle
align the start address down to the cache-line base
issue one read-only 32-bit instruction request per line word
hold each request until downstream req_ready accepts it
consume one response per issued request
assemble response words into little-endian cache-line order
accumulate downstream response errors into line_error_o
present a completed line until line_ready_i accepts it
abort any active refill when flush_i is asserted
avoid producing a completed line for a flushed refill
```

## 3. Interface Contract

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | Refill controller clock. |
| `rst_ni` | input | Active-low asynchronous reset. |
| `flush_i` | input | Aborts active refill and suppresses completion. |
| `start_valid_i` | input | Miss/refill request is valid. |
| `start_ready_o` | output | Refill controller can accept a start request. |
| `start_addr_i` | input | Miss address; low line-offset bits are cleared internally. |
| `line_valid_o` | output | Completed line output is valid. |
| `line_ready_i` | input | Cache accepted the completed line. |
| `line_addr_o` | output | Line-aligned refill address. |
| `line_data_o` | output | Assembled cache line. |
| `line_error_o` | output | At least one downstream response had an error. |
| `mem_if` | initiator | Downstream word read request/response interface. |

## 4. Downstream Request Contract

Every downstream request must be encoded as:

```text
req_write = 0
req_size  = 2  (32-bit word)
req_wdata = 0
req_wstrb = 0
req_instr = 1
```

## 5. Target Requirements

`icache_refill` is target-neutral synthesizable logic and must not change
behavior across IC, Virtex-7 FPGA, or generic simulation targets.
