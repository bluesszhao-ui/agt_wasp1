# dcache_data Design Spec

## 1. Scope

`dcache_data` implements cache-line storage, combinational load word selection,
and store-hit byte-lane merge updates. It does not check tags, sequence
write-through stores, sequence refills, or decide hit/miss policy.

## 2. Editable Block Diagram

```text
editable source: dcache/docs/diagrams/dcache_data_block.graffle
preview export:  none
detail level:    L2
clock domains:   SEQ clk=clk_i; data RAM is not reset
```

The diagram separates lookup address decode, line-RAM state, load word
selection, refill write input, store-hit byte-merge input, and RAM write update
selection.

PNG state diagram:

```text
dcache/docs/images/dcache_data_state.png
```

## 3. Derived Fields

```text
OFFSET_BITS      = clog2(LINE_BYTES)
INDEX_BITS       = clog2(LINE_COUNT)
WORD_INDEX_BITS  = clog2(LINE_BYTES / 4)
lookup_index     = lookup_addr_i[OFFSET_BITS +: INDEX_BITS]
lookup_word_idx  = lookup_addr_i[2 +: WORD_INDEX_BITS]
store_index      = store_addr_i[OFFSET_BITS +: INDEX_BITS]
store_word_idx   = store_addr_i[2 +: WORD_INDEX_BITS]
```

## 4. State

| State element | Reset value | Description |
| --- | --- | --- |
| `data_q` | unspecified | Per-index cache-line data storage. |

Tag valid state determines whether `data_q` contents are usable. Reset does not
clear the data array.

## 5. Update Priority

```text
refill_valid_i:
  data_q[refill_index] = refill_line_i

else store_valid_i:
  data_q[store_index] = data_q[store_index] with selected word bytes merged

otherwise:
  hold state
```

Refill priority is deterministic protection for an unexpected simultaneous
refill/store update. The integrated controller should avoid issuing both writes
to the same data leaf in one cycle.

## 6. Store Merge

`store_wdata_i` is already lane-aligned by `core_lsu`. For each asserted byte
lane in `store_wstrb_i`, the matching byte in the addressed word is replaced.
Unselected bytes and other words in the line are preserved.
