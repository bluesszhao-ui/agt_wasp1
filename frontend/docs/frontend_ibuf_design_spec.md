# frontend_ibuf Design Spec

## 1. Scope

`frontend_ibuf` implements a parameterized, flushable FIFO for instruction
responses. The current frontend integration uses the default depth of two
entries.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Clock/reset domain for all SEQ blocks: clk=clk_i, rst=rst_ni

 IF fetch response
 push_valid/pc/instr/fault/misaligned
           |
           v
 +-----------------------+
 | COMB push_fire/full   |---- push_ready_o
 | flush gate            |
 +----------+------------+
            |
            v
 +-------------------------------+
 | SEQ clk_i/rst_ni              |
 | pc_q/instr_q/fault_q/mis_q    |
 | rd_ptr_q/wr_ptr_q/count_q     |
 +-------------+-----------------+
               |
               v
 +-------------------------------+
 | COMB oldest-entry mux         |---- pop_pc/instr/fault/misaligned
 | pop_fire/empty/flush gate     |---- pop_valid_o, empty_o, full_o
 +-------------+-----------------+
               |
               v
          IF core side
          pop_ready_i
```

PNG state diagram:

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
