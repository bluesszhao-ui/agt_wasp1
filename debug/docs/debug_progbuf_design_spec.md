# debug_progbuf Design Spec

## 1. Scope

The block is a deliberately small four-word flop array. It separates reusable
Program Buffer storage from DMI routing, abstract-command sequencing, and core
instruction execution.

## 2. Editable Register-Transfer Diagram

editable source: `debug/docs/diagrams/debug_progbuf_block.graffle`
preview export: none
detail level: L1
clock domain: `clk_i/rst_ni`

The OmniGraffle diagram separates storage-control inputs, combinational index
selection, the sequential word array, and DMI/future-executor outputs into
distinct `IF`, `COMB`, and `SEQ` blocks. The visible 5 pt grid, native line
segments, V-shaped arrows, endpoint alignment, and element spacing pass the
repository coordinate/overlap audit.

## 3. Sequential Storage

```text
logic [3:0][31:0] words_q
```

The four words are implemented as ordinary flops because the storage is only
128 bits and requires whole-array clear plus a full parallel executor view.
Inferring a RAM would complicate those semantics without a useful area benefit.

The single `always_ff` block implements:

```text
if !rst_ni:          words_q <= 0
else if clear_i:     words_q <= 0
else if write_valid: words_q[write_index_i] <= write_data_i
else:                hold
```

No encoded FSM exists. The meaningful state is the four-word register array,
and the diagram therefore shows register-transfer priority instead of
inventing states.

## 4. Combinational Paths

`read_data_o` is a direct indexed read of `words_q`. `words_o` is a direct
parallel view. Neither path adds a handshake or registered latency; ownership
of DMI response timing and executor sequencing stays outside this leaf.

## 5. Integration Boundary

The storage leaf is now instantiated in `debug_dmi_regs`, where DMI
`progbuf0..3` reads/writes and busy protection are verified. The standalone
`debug_progbuf_exec` sequencer is also independently verified. The next
integration milestone will route postexec and add the halted-core instruction
endpoint. Until that complete path passes,
`debug_dmi_regs.abstractcs.progbufsize` remains zero and OpenOCD continues using
the already verified abstract memory path.

## 6. Target Behavior

No target macro changes the logic. The small flop array is suitable for ASIC
standard-cell synthesis and Virtex-7 register implementation.
