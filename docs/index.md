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
| `common` | design spec, verification plan, verification report |
| `bus` | bus design spec, verification plan, verification report |
| `sram` | AHB SRAM design spec, verification plan, verification report |
| `otp` | AHB OTP design spec, verification plan, verification report |
| `timer` | AHB timer design spec, verification plan, verification report |
| `gpio` | AHB GPIO design spec, verification plan, verification report |
| `uart` | AHB UART design spec, verification plan, verification report |
| `dma` | AHB DMA design spec, verification plan, verification report |

Current bus submodule specs:

```text
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
dma/docs/ahb_dma_design_spec.md
```

## Project Status

See the root-level `ROADMAP.md` for current progress and next steps.
