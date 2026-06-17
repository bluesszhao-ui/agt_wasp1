# dcache_data Spec

## 1. Purpose

`dcache_data` stores direct-mapped data-cache line contents. It supports full
line refill writes, combinational load lookup, and byte-lane store-hit updates.

## 2. Functional Requirements

`dcache_data` must:

```text
decode lookup index and word offset from lookup_addr_i
return the complete cached line at the lookup index
return the 32-bit word selected by lookup_addr_i
write one complete cache line on refill_valid_i
merge store_wdata_i byte lanes selected by store_wstrb_i on store_valid_i
update only the addressed 32-bit word during store-hit merge
make writes visible after the rising clock edge
give refill writes priority over store-hit updates
leave data RAM contents unspecified after reset
```

## 3. Interface Contract

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | D-cache data RAM write clock. |
| `rst_ni` | input | Active-low reset; data contents are not cleared. |
| `lookup_addr_i` | input | Address used for index and word selection. |
| `lookup_index_o` | output | Decoded lookup index. |
| `lookup_word_o` | output | Selected 32-bit word from the cached line. |
| `lookup_line_o` | output | Complete cached line at lookup index. |
| `refill_valid_i` | input | Writes a complete line on the rising clock edge. |
| `refill_addr_i` | input | Refill address whose index selects the line. |
| `refill_line_i` | input | Full refill line payload. |
| `store_valid_i` | input | Store-hit merge update qualifier. |
| `store_addr_i` | input | Store address whose index/word select the update. |
| `store_wdata_i` | input | Store data already aligned to 32-bit byte lanes. |
| `store_wstrb_i` | input | Byte lanes to merge into the cached word. |

## 4. Parameter Contract

| Parameter | Description |
| --- | --- |
| `LINE_COUNT` | Number of direct-mapped cache lines. Must be a power of two for normal cache integration. |
| `LINE_BYTES` | Bytes per cache line. Must be a power of two and a multiple of 4. |
| `ADDR_WIDTH` | Address width, default 32 bits. |
| `DATA_WIDTH` | Data word width, default 32 bits. |

## 5. Target Requirements

The block is functionally target-neutral. For Xilinx Virtex-7 FPGA builds, the
line array may use synthesis attributes to favor distributed RAM mapping.
