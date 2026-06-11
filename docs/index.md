# wasp1 Documentation Index

## Project Architecture

| Document | Purpose |
| --- | --- |
| `wasp1_architecture.md` | SoC baseline and top-level architecture |
| `wasp1_module_hierarchy.md` | First-level module list and submodule hierarchy |
| `wasp1_memory_map.md` | Initial address map and linker layout |
| `wasp1_design_plan.md` | Planned module implementation order |
| `wasp1_verification_plan.md` | Project-wide verification expectations |
| `wasp1_implementation_targets.md` | IC/FPGA target macro policy, including Virtex-7 |
| `wasp1_documentation_policy.md` | Required spec/design spec documentation policy |

## Focus Areas

| Document | Purpose |
| --- | --- |
| `wasp1_debug_strategy.md` | RISC-V debug/OpenOCD/GDB strategy |
| `wasp1_otp_boot_strategy.md` | OTP boot and programming model |
| `wasp1_llvm_s1_plan.md` | LLVM/BSP/toolchain plan |

## Module Documentation

Module-specific documents live under each module's `docs/` directory.

Current module docs:

| Module | Documents |
| --- | --- |
| `common` | spec, design spec, verification plan, verification report |
| `bus` | spec, bus design spec, submodule specs, verification plan, verification report |
| `sram` | AHB SRAM spec, design spec, verification plan, verification report |
| `otp` | AHB OTP spec, design spec, verification plan, verification report |
| `timer` | AHB timer spec, design spec, verification plan, verification report |
| `gpio` | AHB GPIO spec, design spec, verification plan, verification report |
| `uart` | AHB UART and serial submodule specs, design spec, verification plan, verification report |
| `dma` | AHB DMA spec, design spec, verification plan, verification report |
| `intc` | AHB interrupt controller spec, design spec, verification plan, verification report |
| `core` | core spec/design skeleton and core_alu/core_regfile/core_decode/core_branch/core_csr/core_lsu specs, design specs, verification plans, verification reports |

Current implemented block specs:

```text
common/docs/common_spec.md
bus/docs/bus_spec.md
bus/docs/ahb_decoder_spec.md
bus/docs/ahb_default_slave_spec.md
bus/docs/ahb_slave_mux_spec.md
bus/docs/ahb_arbiter_2m_spec.md
bus/docs/ahb_fabric_2m_spec.md
sram/docs/ahb_sram_spec.md
otp/docs/ahb_otp_spec.md
timer/docs/ahb_timer_spec.md
gpio/docs/ahb_gpio_spec.md
uart/docs/ahb_uart_spec.md
uart/docs/uart_baud_spec.md
uart/docs/uart_tx_spec.md
uart/docs/uart_rx_spec.md
dma/docs/ahb_dma_spec.md
intc/docs/ahb_intc_spec.md
core/docs/core_spec.md
core/docs/core_alu_spec.md
core/docs/core_regfile_spec.md
core/docs/core_decode_spec.md
core/docs/core_branch_spec.md
core/docs/core_csr_spec.md
core/docs/core_lsu_spec.md
```

Current implemented block design specs:

```text
common/docs/common_design_spec.md
bus/docs/bus_design_spec.md
bus/docs/ahb_decoder_design_spec.md
bus/docs/ahb_default_slave_design_spec.md
bus/docs/ahb_slave_mux_design_spec.md
bus/docs/ahb_arbiter_2m_design_spec.md
bus/docs/ahb_fabric_2m_design_spec.md
sram/docs/ahb_sram_design_spec.md
otp/docs/ahb_otp_design_spec.md
timer/docs/ahb_timer_design_spec.md
gpio/docs/ahb_gpio_design_spec.md
uart/docs/ahb_uart_design_spec.md
uart/docs/uart_baud_design_spec.md
uart/docs/uart_tx_design_spec.md
uart/docs/uart_rx_design_spec.md
dma/docs/ahb_dma_design_spec.md
intc/docs/ahb_intc_design_spec.md
core/docs/core_design_spec.md
core/docs/core_alu_design_spec.md
core/docs/core_regfile_design_spec.md
core/docs/core_decode_design_spec.md
core/docs/core_branch_design_spec.md
core/docs/core_csr_design_spec.md
core/docs/core_lsu_design_spec.md
```

## Project Status

See the root-level `ROADMAP.md` for current progress and next steps.
