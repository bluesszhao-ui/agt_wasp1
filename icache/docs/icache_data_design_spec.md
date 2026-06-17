# icache_data Design Spec

## 1. Scope

`icache_data` implements direct-mapped cache-line storage and word selection. It
does not track valid bits, compare tags, or sequence refills.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Clock/reset domain for SEQ storage: clk=clk_i
Reset note: rst_ni does not clear data RAM contents

 IF lookup_addr_i
        |
        v
 +-----------------------------+
 | COMB index/word decode      |---- lookup_index_o
 +-------------+---------------+
               |
               v
 +-----------------------------+
 | SEQ line RAM                |
 | clk_i write on refill_valid |
 +-------------+---------------+
               |
               v
 +-----------------------------+
 | COMB line read / word mux   |---- lookup_line_o
 | little-endian word select   |---- lookup_word_o
 +-----------------------------+

 IF refill_addr_i/refill_line_i/refill_valid_i -> SEQ line RAM write port
```

PNG state diagram:

```text
icache/docs/images/icache_data_state.png
```

## 3. Derived Fields

```text
LINE_BITS       = LINE_BYTES * 8
DATA_BYTES      = DATA_WIDTH / 8
OFFSET_BITS     = clog2(LINE_BYTES)
INDEX_BITS      = clog2(LINE_COUNT)
WORDS_PER_LINE  = LINE_BYTES / DATA_BYTES
WORD_INDEX_BITS = clog2(WORDS_PER_LINE)
BYTE_OFFSET_BITS = clog2(DATA_BYTES)
index           = addr[OFFSET_BITS +: INDEX_BITS]
word_index      = addr[BYTE_OFFSET_BITS +: WORD_INDEX_BITS]
```

## 4. State

| State element | Reset value | Description |
| --- | --- | --- |
| `data_q[LINE_COUNT]` | unspecified | Direct-mapped cache line storage. |

The data RAM is intentionally not reset. `icache_tag.valid_q` determines whether
line contents can be architecturally consumed.

## 5. Write Behavior

```text
posedge clk_i:
  if refill_valid_i:
    data_q[refill_index] = refill_line_i
```

There is no byte-enable path in this leaf. Refill always writes a complete line.

## 6. Read and Word Select Behavior

Lookup is combinational from current line storage:

```text
lookup_line_o = data_q[lookup_index]
lookup_word_o = lookup_line_o[word_index * DATA_WIDTH +: DATA_WIDTH]
```

Word offset zero selects bits `[31:0]`, matching little-endian instruction word
layout in the line.
