# core_wb Design Spec

## 1. Scope

`core_wb` is a combinational helper at the execute/writeback boundary of the
planned simple in-order core pipeline.

## 2. Editable Block Diagram

```text
editable source: core/docs/diagrams/core_wb_block.graffle
preview export:  none
detail level:    L1
clock domains:   none; pure combinational logic
```

The diagram separates candidate writeback data inputs, the source mux,
retirement/write qualifiers, write-enable generation, and the register-file
write interface. The destination register state is owned by `core_regfile`.

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
