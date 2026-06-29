# dcache_store Design Spec

## 1. Scope

`dcache_store` implements a single-outstanding write-through store FSM. It owns
only request capture, downstream write sequencing, response error capture, and
completion handoff.

## 2. Editable Block Diagram

```text
editable source: dcache/docs/diagrams/dcache_store_block.graffle
preview export:  none
detail level:    L2
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The diagram separates store start input, start-fire/ready logic, store FSM and
captured request state, downstream write request encoding, response/done
control, downstream memory interface, and completed-store output.

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
