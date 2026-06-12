# core_wb Design Spec

## 1. Scope

`core_wb` is a combinational helper at the execute/writeback boundary of the
planned simple in-order core pipeline.

## 2. Block Diagram

```text
 alu/load/csr/pc4/imm data ---> source mux ----> rf_wdata
                                     ^
                                     |
                                wb_sel_i

 valid/rd_write/rd/trap/fault ---> write qualifier ---> rf_we
 rd_i ------------------------------------------------> rf_waddr
```

## 3. Design

The data mux uses `core_wb_sel_e`:

```text
CORE_WB_ALU  -> alu_result_i
CORE_WB_LOAD -> load_data_i
CORE_WB_CSR  -> csr_rdata_i
CORE_WB_PC4  -> pc_plus4_i
CORE_WB_IMM  -> imm_u_i
default      -> alu_result_i
```

The write qualifier drops writes when the slot is invalid, decode did not mark
the instruction as writing `rd`, `rd` is `x0`, a trap is retiring, or a late
fault is retiring.

## 4. Target Support

The module is target-neutral combinational logic. No IC or FPGA-specific
primitive is required.
