# core_regfile Design Spec

## 1. Scope

`core_regfile` is the integer register storage submodule for the RV32I core.

## 2. Block Diagram

```text
                  +----------------------+
 clk_i ---------->|                      |
 rst_ni --------->|  regs_q x1..x31      |
 we_i ----------->|  rising-edge write   |
 waddr_i -------->|                      |
 wdata_i -------->|                      |
                  +-----+----------+-----+
                        |          |
                        v          v
 raddr1_i --->+----------------+ +----------------+<--- raddr2_i
              | x0/bypass/read | | x0/bypass/read |
 waddr_i ---->| mux            | | mux            |<--- waddr_i
 wdata_i ---->|                | |                |<--- wdata_i
 we_i ------->+-------+--------+ +--------+-------+<--- we_i
                      |                   |
                      v                   v
                   rdata1_o            rdata2_o
```

## 3. Design

The storage array contains only registers `x1` through `x31`; `x0` is not
physically stored.

The write path ignores writes when `waddr_i` is zero. For nonzero write
addresses, `wdata_i` is committed to `regs_q[waddr_i]` on the rising clock
edge.

Each read port uses a combinational priority:

```text
1. address zero returns 0
2. matching active write to a nonzero address returns wdata_i
3. otherwise return regs_q[address]
```

## 4. Target Support

The register file uses synthesizable flip-flop array RTL. It is portable across
IC and Xilinx Virtex-7 FPGA targets. No target primitive is required.
