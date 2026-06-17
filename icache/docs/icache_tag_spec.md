# icache_tag Spec

## 1. Purpose

`icache_tag` stores per-line valid bits and tags for a direct-mapped instruction
cache.

## 2. Functional Requirements

`icache_tag` must:

```text
decode lookup index and tag from lookup_addr_i
assert lookup_hit_o only when lookup_valid_i is high, the line is valid, and the stored tag matches
expose the decoded lookup index
update the refill index with the refill tag on refill_valid_i
mark a refilled line valid only when refill_error_i is low
mark a refill-error line invalid
clear every valid bit on reset
clear every valid bit on invalidate_i
give invalidate priority over refill update
```

## 3. Interface Contract

| Signal | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | I-cache tag clock. |
| `rst_ni` | input | Active-low asynchronous reset. |
| `invalidate_i` | input | Clears every valid bit on the next rising clock. |
| `lookup_valid_i` | input | Qualifies lookup hit calculation. |
| `lookup_addr_i` | input | Address used for index and tag comparison. |
| `lookup_hit_o` | output | Lookup hits a valid matching tag. |
| `lookup_index_o` | output | Decoded lookup index. |
| `refill_valid_i` | input | Refill tag update qualifier. |
| `refill_addr_i` | input | Refill address used for index and tag write. |
| `refill_error_i` | input | Refill failed; the indexed line must not become valid. |

## 4. Parameter Contract

| Parameter | Description |
| --- | --- |
| `LINE_COUNT` | Number of direct-mapped cache lines. Must be a power of two for normal cache integration. |
| `LINE_BYTES` | Bytes per cache line. Must be a power of two for normal cache integration. |
| `ADDR_WIDTH` | Address width, default 32 bits. |

## 5. Target Requirements

The block is functionally target-neutral. For Xilinx Virtex-7 FPGA builds, the
tag array may use synthesis attributes to favor distributed RAM mapping.
