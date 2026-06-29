# icache_tag Design Spec

## 1. Scope

`icache_tag` implements direct-mapped valid/tag storage and lookup comparison.
It does not store cache data, sequence refills, or talk directly to AHB-Lite.

## 2. Editable Block Diagram

```text
editable source: icache/docs/diagrams/icache_tag_block.graffle
preview export:  none
detail level:    L1
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The diagram separates lookup inputs, index/tag extraction, valid/tag sequential
state, hit comparison, refill/invalidate update selection, and outputs.

PNG state diagram:

```text
icache/docs/images/icache_tag_state.png
```

## 3. Derived Fields

```text
OFFSET_BITS = clog2(LINE_BYTES)
INDEX_BITS  = clog2(LINE_COUNT)
TAG_BITS    = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS
index       = addr[OFFSET_BITS +: INDEX_BITS]
tag         = addr[ADDR_WIDTH-1 -: TAG_BITS]
```

## 4. State

| State element | Reset value | Description |
| --- | --- | --- |
| `valid_q` | `0` | Per-line valid bits. |
| `tag_q` | don't care while invalid | Per-line stored tag. |

## 5. State Update Priority

```text
reset:
  valid_q = 0

invalidate_i:
  valid_q = 0

refill_valid_i:
  tag_q[refill_index] = refill_tag
  valid_q[refill_index] = !refill_error_i

otherwise:
  hold state
```

Invalidate has priority over refill. A refill error writes the tag but keeps the
line invalid, so the failed line cannot hit.

## 6. Lookup Behavior

Lookup is combinational from the current registered state:

```text
lookup_hit_o = lookup_valid_i &&
               valid_q[lookup_index] &&
               tag_q[lookup_index] == lookup_tag
```

When `lookup_valid_i` is low, `lookup_hit_o` is low.
