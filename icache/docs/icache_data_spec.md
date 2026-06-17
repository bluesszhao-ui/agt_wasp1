# icache_data Spec

## 1. Purpose

`icache_data` stores direct-mapped instruction cache line data and returns the
32-bit instruction word selected by a lookup address.

## 2. Functional Requirements

`icache_data` must:

```text
decode lookup index from lookup_addr_i
decode word offset from lookup_addr_i
return the complete cache line at the lookup index
return the selected 32-bit word from the cache line
write one complete cache line on refill_valid_i
write the refill line to the index decoded from refill_addr_i
make refill data visible after the write clock edge
leave data RAM contents unspecified after reset
```

The tag array controls validity. Data contents after reset or for invalid tag
lines must not be consumed by cache control logic.

## 3. Interface Contract

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | I-cache data clock for refill writes. |
| `rst_ni` | input | Active-low reset input; data contents are not cleared. |
| `lookup_addr_i` | input | Address used to select line index and word offset. |
| `lookup_index_o` | output | Decoded lookup line index. |
| `lookup_word_o` | output | Selected 32-bit instruction word. |
| `lookup_line_o` | output | Complete cached line at the lookup index. |
| `refill_valid_i` | input | Refill writes a complete line on the rising clock edge. |
| `refill_addr_i` | input | Address used to select refill destination index. |
| `refill_line_i` | input | Full line data written by refill. |

## 4. Parameter Contract

| Parameter | Description |
| --- | --- |
| `LINE_COUNT` | Number of direct-mapped cache lines. |
| `LINE_BYTES` | Bytes per cache line. |
| `ADDR_WIDTH` | Address width, default 32 bits. |
| `DATA_WIDTH` | Instruction word width, default 32 bits. |

Normal wasp1 integration uses 32-bit words and 16-byte lines.

## 5. Target Requirements

The block is functionally target-neutral. For Xilinx Virtex-7 FPGA builds, the
line array may use synthesis attributes to favor distributed RAM mapping with a
combinational read path.
