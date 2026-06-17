# dcache_store Design Spec

## 1. Scope

`dcache_store` implements a single-outstanding write-through store FSM. It owns
only request capture, downstream write sequencing, response error capture, and
completion handoff.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Clock/reset domain for SEQ blocks: clk=clk_i, rst=rst_ni

 IF start_valid/addr/size/wdata/wstrb
          |
          v
 +-----------------------------+
 | COMB start fire / ready     |---- start_ready_o
 +--------------+--------------+
                |
                v
 +-----------------------------+
 | SEQ store FSM               |
 | clk=clk_i rst=rst_ni        |
 | state_q/addr_q/size_q       |
 | wdata_q/wstrb_q/error_q     |
 +------+--------------+-------+
        |              ^
        v              |
 +-------------+   +----------------+
 | COMB write  |   | COMB response  |
 | req encoder |   | done controls  |
 +------+------+   +-------+--------+
        |                  |
        v                  v
 IF downstream mem_if   IF done_valid/payload/error
```

PNG state diagram:

```text
dcache/docs/images/dcache_store_fsm.png
```

## 3. FSM

```text
STORE_IDLE
  start_valid_i && start_ready_o:
    capture address, size, write data, and byte strobes
    clear error
    -> STORE_REQ

STORE_REQ
  mem_if.req_valid && mem_if.req_ready:
    downstream write request accepted
    -> STORE_WAIT

STORE_WAIT
  mem_if.rsp_valid && mem_if.rsp_ready:
    capture mem_if.rsp_err
    -> STORE_DONE

STORE_DONE
  done_valid_o && done_ready_i:
    clear error
    -> STORE_IDLE
```

`flush_i` has priority over normal FSM progress and returns the controller to
`STORE_IDLE` without producing `done_valid_o`.

## 4. Request Encoding

The downstream request is a data write:

```text
req_write = 1
req_instr = 0
req_addr  = addr_q
req_size  = size_q
req_wdata = wdata_q
req_wstrb = wstrb_q
```

The captured fields are stable from `STORE_REQ` through `STORE_DONE`.

## 5. Backpressure Behavior

Downstream request valid remains asserted in `STORE_REQ` until `req_ready` is
high. Downstream response ready is asserted in `STORE_WAIT`. Completed store
outputs remain stable in `STORE_DONE` until `done_ready_i` is high.
