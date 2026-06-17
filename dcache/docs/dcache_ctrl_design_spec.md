# dcache_ctrl Design Spec

## 1. Scope

`dcache_ctrl` implements the D-cache load/store hit/miss control FSM. It does
not store tag bits, cache-line data, refill beat state, or downstream store
transaction state; those are owned by `dcache_tag`, `dcache_data`,
`dcache_refill`, and `dcache_store`.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Clock/reset domain for SEQ blocks: clk=clk_i, rst=rst_ni

 IF core_if.req
        |
        v
 +-----------------------------+
 | COMB request classify       |
 | invalid/load/store/hit/miss |
 +-----+-----------------------+
       | lookup_valid_o/lookup_addr_o
       v
 IF tag_hit_i/data_word_i
       |
       v
 +-----------------------------+
 | SEQ control FSM             |
 | clk=clk_i rst=rst_ni        |
 | state_q/request registers   |
 | store_hit_q/rsp registers   |
 +---+-----------+-------------+
     |           |
     |           +------------------+
     |                              |
     v                              v
 +------------------+       +------------------+
 | COMB refill      |       | COMB store       |
 | start/update     |       | start/update     |
 +--------+---------+       +--------+---------+
          |                          |
          v                          v
    IF dcache_refill           IF dcache_store
          |                          |
          +-----------+--------------+
                      |
                      v
             +------------------+
             | COMB response    |
             | data/error mux   |
             +--------+---------+
                      |
                      v
                IF core_if.rsp
```

PNG state diagram:

```text
dcache/docs/images/dcache_ctrl_fsm.png
```

## 3. FSM

```text
CTRL_IDLE
  core_if.req_valid && core_if.req_ready && invalid_req:
    capture request
    rsp_data_q = 0
    rsp_err_q = 1
    -> CTRL_RESP

  core_if.req_valid && core_if.req_ready && load && tag_hit_i:
    capture request
    rsp_data_q = data_word_i
    rsp_err_q = 0
    -> CTRL_RESP

  core_if.req_valid && core_if.req_ready && load && !tag_hit_i:
    capture miss address
    -> CTRL_LOAD_REFILL_REQ

  core_if.req_valid && core_if.req_ready && store:
    capture store fields and store_hit_q
    -> CTRL_STORE_REQ

CTRL_LOAD_REFILL_REQ
  refill_start_valid_o && refill_start_ready_i:
    refill start accepted
    -> CTRL_LOAD_REFILL_WAIT

CTRL_LOAD_REFILL_WAIT
  refill_line_valid_i && refill_line_ready_o:
    pulse tag/data refill update outputs
    select requested word from refill_line_data_i
    rsp_err_q = refill_line_error_i
    -> CTRL_RESP

CTRL_STORE_REQ
  store_start_valid_o && store_start_ready_i:
    store transaction accepted by dcache_store
    -> CTRL_STORE_WAIT

CTRL_STORE_WAIT
  store_done_valid_i && store_done_ready_o:
    if store_hit_q && !store_done_error_i:
      pulse data_store_valid_o
    rsp_data_q = 0
    rsp_err_q = store_done_error_i
    -> CTRL_RESP

CTRL_RESP
  core_if.rsp_valid && core_if.rsp_ready:
    response accepted
    -> CTRL_IDLE
```

`flush_i` has priority over normal FSM progress and returns the FSM to
`CTRL_IDLE`. During flush, core responses, refill accepts, store accepts, and
cache update pulses are suppressed.

## 4. Datapath

```text
invalid_req =
  core_if.req_instr
  || core_if.req_size == 3
  || natural-alignment violation for req_size

req_word_index = req_addr_q[$clog2(DATA_BYTES) +: $clog2(WORDS_PER_LINE)]
refill_word = refill_line_data_i[req_word_index * DATA_WIDTH +: DATA_WIDTH]
```

The implementation uses bounded `for` loops for refill word selection so the
logic remains synthesizable and parameter-safe.

## 5. Backpressure

Core request ready is asserted only in `CTRL_IDLE`. Core response valid is held
in `CTRL_RESP` until `core_if.rsp_ready` is high. Refill start valid is held in
`CTRL_LOAD_REFILL_REQ` until `refill_start_ready_i` is high. Store start valid
is held in `CTRL_STORE_REQ` until `store_start_ready_i` is high.

Refill line ready and store done ready are asserted only in their matching wait
states, which keeps update pulses one cycle wide and tied to accepted
subordinate completions.
