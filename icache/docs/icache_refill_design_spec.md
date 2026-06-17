# icache_refill Design Spec

## 1. Scope

`icache_refill` is the line-refill sequencer for the instruction cache. It
issues downstream word reads and assembles a complete cache line. It does not
perform tag comparison or decide whether a frontend request hits or misses.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Clock/reset domain for SEQ blocks: clk=clk_i, rst=rst_ni

 IF start_valid/start_addr
          |
          v
 +----------------------------+
 | COMB line align / fire     |---- start_ready_o
 +-------------+--------------+
               |
               v
 +----------------------------+
 | SEQ refill FSM             |
 | state_q/line_addr_q/beat_q |
 | line_data_q/error_q        |
 +------+-------------+-------+
        |             ^
        v             |
 +-------------+  +----------------+
 | COMB req    |  | COMB rsp/store |
 | encoder     |  | next controls  |
 +------+------+  +-------+--------+
        |                 |
        v                 v
 IF downstream mem_if  IF line_valid/line_data/error
```

PNG state diagram:

```text
icache/docs/images/icache_refill_fsm.png
```

## 3. FSM

```text
REFILL_IDLE
  start_valid_i && start_ready_o:
    capture aligned start address
    clear line data, beat, and error
    -> REFILL_REQ

REFILL_REQ
  mem_if.req_valid && mem_if.req_ready:
    current word request accepted
    -> REFILL_WAIT

REFILL_WAIT
  mem_if.rsp_valid && mem_if.rsp_ready && !last_beat:
    store response word at beat offset
    accumulate rsp_err
    beat_q++
    -> REFILL_REQ

  mem_if.rsp_valid && mem_if.rsp_ready && last_beat:
    store final response word
    accumulate rsp_err
    -> REFILL_DONE

REFILL_DONE
  line_valid_o && line_ready_i:
    clear beat/error
    -> REFILL_IDLE
```

`flush_i` has priority over normal FSM progress and returns the controller to
`REFILL_IDLE` without producing `line_valid_o`.

## 4. Address and Line Assembly

```text
line_addr_q = start_addr_i with low clog2(LINE_BYTES) bits cleared
request address = line_addr_q + beat_q * 4
line_data_q[beat_q * DATA_WIDTH +: DATA_WIDTH] = mem_if.rsp_rdata
line_error_o = OR of all response errors in the line
```

Word beat zero maps to bits `[31:0]` of the cache line.

## 5. Backpressure Behavior

Downstream request valid remains asserted in `REFILL_REQ` until `req_ready` is
high. Downstream response ready is asserted in `REFILL_WAIT`. Completed line
outputs remain stable in `REFILL_DONE` until `line_ready_i` is high.
