# icache_ctrl Design Spec

## 1. Scope

`icache_ctrl` implements the I-cache hit/miss control FSM. It does not store tag
bits, cache-line data, or refill beat state; those are owned by `icache_tag`,
`icache_data`, and `icache_refill`.

## 2. Editable Block Diagram

```text
editable source: icache/docs/diagrams/icache_ctrl_block.graffle
preview export:  none
detail level:    L2
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The diagram separates frontend request classification, tag/data inputs, control
FSM state, refill start/update controls, refill interface, response muxing, and
frontend response output.

PNG state diagram:

```text
icache/docs/images/icache_ctrl_fsm.png
```

## 3. FSM

```text
CTRL_IDLE
  front_if.req_valid && front_if.req_ready && invalid_req:
    capture request address
    rsp_data_q = 0
    rsp_err_q = 1
    -> CTRL_RESP

  front_if.req_valid && front_if.req_ready && !invalid_req && tag_hit_i:
    capture request address
    rsp_data_q = data_word_i
    rsp_err_q = 0
    -> CTRL_RESP

  front_if.req_valid && front_if.req_ready && !invalid_req && !tag_hit_i:
    capture miss address
    -> CTRL_MISS_REQ

CTRL_MISS_REQ
  refill_start_valid_o && refill_start_ready_i:
    refill start accepted
    -> CTRL_MISS_WAIT

CTRL_MISS_WAIT
  refill_line_valid_i && refill_line_ready_o:
    pulse tag/data refill update outputs
    select requested word from refill_line_data_i
    rsp_err_q = refill_line_error_i
    -> CTRL_RESP

CTRL_RESP
  front_if.rsp_valid && front_if.rsp_ready:
    response accepted
    -> CTRL_IDLE
```

`flush_i` has priority over normal FSM progress and returns the FSM to
`CTRL_IDLE`. During flush, frontend response valid and refill/update accepts are
suppressed.

## 4. Datapath

```text
invalid_req =
  front_if.req_write
  || front_if.req_size != 2
  || !front_if.req_instr
  || front_if.req_addr[1:0] != 0

miss_word_index = miss_addr_q[$clog2(DATA_BYTES) +: $clog2(WORDS_PER_LINE)]
refill_word = refill_line_data_i[miss_word_index * DATA_WIDTH +: DATA_WIDTH]
```

The implementation uses a bounded `for` loop for refill word selection so the
logic remains synthesizable and parameter-safe.

## 5. Backpressure

Frontend request ready is asserted only in `CTRL_IDLE`. Frontend response valid
is held in `CTRL_RESP` until `front_if.rsp_ready` is high. Refill start valid is
held in `CTRL_MISS_REQ` until `refill_start_ready_i` is high. Refill line ready
is asserted only in `CTRL_MISS_WAIT`.
