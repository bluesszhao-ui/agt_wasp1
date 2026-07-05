# dcache_uncached Design Spec

## 1. Scope

`dcache_uncached` is a small single-transaction sequencer for non-cacheable
D-cache accesses. It owns only the request/response holding registers needed to
survive downstream and controller backpressure.

## 2. Block Diagram Status

```text
editable source: pending dcache/docs/diagrams/dcache_uncached_block.graffle
detail level:    L2
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The required diagram should show separate SEQ request/response registers, COMB
handshake logic, the downstream `mem_if`, and the `done_*` response interface.

## 3. FSM

```text
UNCACHED_IDLE
  start_valid_i && start_ready_o:
    capture start_addr_i/start_write_i/start_size_i/start_wdata_i/start_wstrb_i
    clear held response
    -> UNCACHED_REQ

UNCACHED_REQ
  mem_if.req_valid && mem_if.req_ready:
    downstream accepted the single address/data phase
    -> UNCACHED_WAIT

UNCACHED_WAIT
  mem_if.rsp_valid && mem_if.rsp_ready:
    capture mem_if.rsp_rdata and mem_if.rsp_err
    -> UNCACHED_DONE

UNCACHED_DONE
  done_valid_o && done_ready_i:
    completion accepted by dcache_ctrl
    clear held response
    -> UNCACHED_IDLE
```

`flush_i` has priority over normal progress and returns the FSM to
`UNCACHED_IDLE`. During flush, downstream request valid, downstream response
ready, and completion valid are all suppressed.

## 4. Datapath

Request fields are captured at start acceptance and then directly drive the
downstream request interface while the FSM is in `UNCACHED_REQ`.

```text
mem_if.req_addr  = addr_q
mem_if.req_write = write_q
mem_if.req_size  = size_q
mem_if.req_wdata = wdata_q
mem_if.req_wstrb = wstrb_q
mem_if.req_instr = 0
```

For stores, downstream read data is ignored by software convention, but the
sequencer still captures the response data so the completion path remains
uniform for loads and stores.

## 5. Verification

The first verification point is integrated in `tb_dcache`: two consecutive
loads to the same MMIO address must both issue downstream reads and may return
different data values, proving the first value was not cached. A directed
uncached write also checks pass-through write address, data, strobes, and
response handling.
