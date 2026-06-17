# icache_ctrl Spec

## 1. Purpose

`icache_ctrl` is the instruction-cache control leaf. It accepts frontend fetch
requests, consumes tag/data lookup results, starts cache-line refills on misses,
updates tag/data storage after refill completion, and returns one fetch response
per accepted frontend request unless the request is flushed before completion.

## 2. Interfaces

Clock/reset:

```text
clk_i   I-cache control clock
rst_ni  active-low asynchronous reset
flush_i synchronous abort for active control work
```

Frontend interface:

```text
front_if.target
  accepted request must be a read-only 32-bit instruction fetch
  response data is a 32-bit instruction word
  response error marks fetch fault
```

Tag/data lookup:

```text
lookup_valid_o  qualifies lookup_addr_o for tag comparison
lookup_addr_o   address presented to tag and data leaves
tag_hit_i       hit result for lookup_addr_o
data_word_i     cached instruction word for lookup_addr_o
```

Refill interface:

```text
refill_start_valid_o/refill_start_ready_i/refill_start_addr_o
  starts a cache-line refill for a miss address

refill_line_valid_i/refill_line_ready_o/refill_line_addr_i/refill_line_data_i/refill_line_error_i
  transfers one completed refill line back to the cache
```

Tag/data update:

```text
tag_refill_valid_o/tag_refill_addr_o/tag_refill_error_o
data_refill_valid_o/data_refill_addr_o/data_refill_line_o
  pulse when a completed refill line is accepted
```

## 3. Functional Requirements

`icache_ctrl` must:

```text
accept one frontend request at a time
return a hit response from data_word_i
start exactly one refill for a miss
select the requested 32-bit word from the completed refill line
return refill_line_error_i as the frontend response error
write tag and data leaves when a refill line is accepted
fault invalid frontend requests without starting refill
hold response stable under frontend response backpressure
hold refill start valid under refill start backpressure
abort active work when flush_i is asserted
forward flush_i to the refill sequencer through refill_flush_o
```

Invalid frontend requests are:

```text
write requests
non-word requests
non-instruction requests
misaligned addresses with addr[1:0] != 0
```

## 4. Target Behavior

The controller contains only target-neutral registers and combinational logic.
The following target macros must not change its programmer-visible behavior:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
