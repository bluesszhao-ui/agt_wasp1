# frontend_ibuf Design Spec

## 1. Scope

`frontend_ibuf` implements a parameterized, flushable FIFO for instruction
responses. The current frontend integration uses the default depth of two
entries.

## 2. Editable Block Diagram

```text
editable source: frontend/docs/diagrams/frontend_ibuf_block.graffle
preview export:  none
detail level:    L1
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The diagram separates fetch response input, combinational push gating, FIFO
storage and pointer/count state, combinational oldest-entry/pop logic, core
output, and flush/pop-ready control.

Legacy PNG state diagram:

```text
frontend/docs/images/frontend_ibuf_state.png
```

## 3. State

| State element | Reset value | Description |
| --- | --- | --- |
| `pc_q[DEPTH]` | don't care while empty | FIFO PC storage. |
| `instr_q[DEPTH]` | don't care while empty | FIFO instruction storage. |
| `fault_q[DEPTH]` | don't care while empty | FIFO fetch fault storage. |
| `misaligned_q[DEPTH]` | don't care while empty | FIFO misaligned-PC flag storage. |
| `rd_ptr_q` | `0` | Points to the oldest queued entry. |
| `wr_ptr_q` | `0` | Points to the next write slot. |
| `count_q` | `0` | Number of valid queued entries. |

## 4. Register-Transfer Behavior

```text
reset:
  rd_ptr_q = 0
  wr_ptr_q = 0
  count_q  = 0

flush_i:
  rd_ptr_q = 0
  wr_ptr_q = 0
  count_q  = 0

push_fire && !pop_fire:
  write push payload at wr_ptr_q
  wr_ptr_q = ptr_inc(wr_ptr_q)
  count_q  = count_q + 1

!push_fire && pop_fire:
  rd_ptr_q = ptr_inc(rd_ptr_q)
  count_q  = count_q - 1

push_fire && pop_fire:
  write push payload at wr_ptr_q
  wr_ptr_q = ptr_inc(wr_ptr_q)
  rd_ptr_q = ptr_inc(rd_ptr_q)
  count_q  = count_q
```

`ptr_inc` wraps from `DEPTH-1` to zero.

## 5. Combinational Outputs

```text
empty_o      = count_q == 0
full_o       = count_q == DEPTH
push_ready_o = !full_o && !flush_i
pop_valid_o  = !empty_o && !flush_i
pop payload  = storage at rd_ptr_q
```

## 6. Priority Notes

Flush has highest priority and drops all queued data. While `flush_i` is high,
`push_ready_o` and `pop_valid_o` are low, so no externally visible push or pop
handshake occurs.

The design intentionally does not bypass a same-cycle push to an empty pop. That
keeps the FIFO simple and gives the consumer the new entry on the next cycle.
