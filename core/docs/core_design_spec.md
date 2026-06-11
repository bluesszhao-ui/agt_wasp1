# core Design Spec

## 1. Scope

`core` is planned as a simple in-order RV32I + Zicsr machine-mode core.

## 2. Planned Block Diagram

```text
       frontend response
              |
              v
      +---------------+
      | core_pipe     |
      | IF/ID/EX-WB   |
      +-------+-------+
              |
     +--------+---------+
     |                  |
     v                  v
 +----------+      +-----------+
 | decode   |----->| regfile   |
 +----+-----+      +-----+-----+
      |                  |
      v                  v
 +----------+      +-----------+
 | ALU      |<-----| operands  |
 +----+-----+      +-----------+
      |
      +---- branch / jump
      |
      +---- LSU request
      |
      +---- CSR / trap path
```

## 3. Implementation Staging

The core is implemented submodule by submodule:

```text
1. core_alu
2. core_regfile
3. core_decode
4. core_branch
5. core_csr
6. core_lsu
7. core_trap
8. core_hazard
9. core_wb
10. core_pipe
11. core top integration
```

Each submodule receives its own spec, design spec, testbench, and verification
report when it has a standalone behavioral contract.

## 4. Target Support

Core RTL is target-neutral synthesizable logic and must lint for:

```text
generic simulation
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
