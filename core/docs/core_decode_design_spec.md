# core_decode Design Spec

## 1. Scope

`core_decode` is a combinational instruction decoder.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic
All logic blocks in this diagram are COMB. No DUT clock/reset is used.

 instr_i[31:0]
      |
      v
 +-------------------+
 | COMB field extract|
 | opcode/funct/regs |
 +---------+---------+
           |
           v
 +-------------------+       +----------------+
 | COMB opcode case  |------>| COMB illegal   |
 +----+----+----+----+       +--------+-------+
      |    |    |                     |
      |    |    +------ immediates ---+
      |    +----------- control flags |
      +---------------- reg fields    |
           |
           v
 decoded pipeline control outputs
```

## 3. Design

The module uses one `always_comb` block with defaults for every output.

The top-level case dispatches on `instr_i[6:0]`. Nested cases decode `funct3`
and `funct7` where required.

Register specifier outputs always expose the raw instruction fields. Separate
`uses_rs1_o`, `uses_rs2_o`, and `writes_rd_o` signals tell later pipeline
stages whether those fields are architecturally consumed.

Immediate generation is performed in decode so downstream modules can share a
single sign-extension interpretation.

## 4. Illegal Encoding Policy

The decoder marks an instruction illegal when the encoding is outside the
accepted RV32I + Zicsr machine-mode subset. Illegal instructions still expose
raw register fields and best-effort class defaults, but the pipeline must use
`illegal_o` to redirect into the trap path.

## 5. Target Support

The decoder is target-neutral combinational logic. No IC or FPGA-specific
primitive is required.
