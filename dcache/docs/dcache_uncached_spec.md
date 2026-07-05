# dcache_uncached Spec

## 1. Purpose

`dcache_uncached` is the D-cache leaf that services non-cacheable data accesses,
especially peripheral MMIO. It issues exactly one downstream transaction per
accepted request and never allocates, fills, merges, or invalidates cache-line
state.

## 2. Interfaces

Clock/reset:

```text
clk_i    D-cache clock
rst_ni   active-low asynchronous reset
flush_i  synchronous abort for active uncached work
```

Start interface:

```text
start_valid_i/start_ready_o  accepts one uncached access
start_addr_i                 byte address
start_write_i                1=write, 0=read
start_size_i                 byte/halfword/word size
start_wdata_i                write payload
start_wstrb_i                write byte enables
```

Completion interface:

```text
done_valid_o/done_ready_i  returns one completion to dcache_ctrl
done_rdata_o              downstream read data for loads
done_error_o              downstream error response
```

Downstream interface:

```text
mem_if.initiator  one valid/ready request-response transaction
```

## 3. Functional Requirements

`dcache_uncached` must:

```text
accept one request only while idle
hold request address, write, size, data, and strobes stable under backpressure
issue exactly one downstream request per accepted start
consume exactly one downstream response
return read data and error status to dcache_ctrl
hold completion stable until accepted
never request an instruction transaction
abort active work on flush_i without producing a stale completion
reset to idle with no valid request or completion
```

## 4. Cacheability Contract

The module is intentionally unaware of the memory map. `dcache` and
`dcache_ctrl` decide whether a request is cacheable. Once routed here, the
access is treated as device-like:

```text
load:  one downstream read, no allocation
store: one downstream write, no cache update
```

This prevents stale peripheral register values, such as INTC `CLAIM`, from
being returned out of cached data lines.
