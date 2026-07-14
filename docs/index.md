# wasp1 Documentation Index

## Project Architecture

| Document | Purpose |
| --- | --- |
| `wasp1_architecture.md` | SoC baseline and top-level architecture |
| `wasp1_module_hierarchy.md` | First-level module list and submodule hierarchy |
| `wasp1_memory_map.md` | Initial address map and linker layout |
| `wasp1_memory_macro_replacement.md` | SRAM/OTP memory macro replacement and gate-count accounting policy |
| `wasp1_design_plan.md` | Planned module implementation order |
| `wasp1_verification_plan.md` | Project-wide verification expectations |
| `wasp1_implementation_targets.md` | IC/FPGA target macro policy, including Virtex-7 |
| `wasp1_documentation_policy.md` | Required spec/design spec documentation policy |
| `wasp1_omnigraffle_diagram_policy.md` | Stable OmniGraffle drawing policy for editable block/FSM figures |
| `../ROADMAP.md` | Current implementation, verification, documentation, and residual-work status |

## Focus Areas

| Document | Purpose |
| --- | --- |
| `wasp1_debug_strategy.md` | RISC-V debug/OpenOCD/GDB strategy |
| `wasp1_otp_boot_strategy.md` | OTP boot and programming model |
| `wasp1_llvm_s1_plan.md` | LLVM/BSP/toolchain plan and stage-1 BSP status |
| `../wasp1/docs/wasp1_cache_metrics.md` | Top-level C firmware cache hit-rate and runtime-efficiency metrics |
| `../wasp1/dc/README.md` | ASIC/DC and Virtex-7/Vivado synthesis collateral entry points |
| `../ftdi_debugger/docs/ftdi_debugger_spec.md` | FT2232H external debugger requirements |
| `../ftdi_debugger/docs/ftdi_debugger_pinout.md` | FTDI debugger stage-1 pinout and schematic constraints |
| `../ftdi_debugger/docs/ftdi_debugger_design_plan.md` | FTDI debugger hardware design plan |
| `../ftdi_debugger/docs/ftdi_debugger_revA_design_spec.md` | Frozen Rev A component, power, isolation, signal, and PCB design decisions |
| `../ftdi_debugger/docs/ftdi_debugger_verification_plan.md` | FTDI debugger board bring-up and verification plan |
| `../ftdi_debugger/docs/ftdi_debugger_verification_report.md` | FTDI debugger collateral check report |
| `../ftdi_debugger/docs/ftdi_debugger_manufacturing_review_report.md` | FTDI debugger Rev A manufacturing audit findings and release holds |
| `../ftdi_debugger/hw/fabrication/wasp1_ft2232h_debugger_revA_release_checklist.md` | Controlled manufacturing release gates and sign-off table |
| `../llvm_s1/toolchain/docs/wasp1_toolchain_setup.md` | LLVM toolchain discovery, local build, and strict smoke-test setup |

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
| `core` | core spec/design skeleton and core_alu/core_regfile/core_decode/core_branch/core_csr/core_lsu/core_trap/core_hazard/core_wb/core_debug_ctrl/core_pipe/core_int_datapath specs, design specs, verification plans, verification reports |
| `debug` | DMI, halt control, GPR transport, and abstract-command specs, design specs, verification plans, verification reports |
| `frontend` | PC, fetch, instruction buffer, top specs, design specs, verification plans, verification reports |
| `icache` | integrated I-cache and tag/data/refill/control specs, design specs, verification plans, verification reports |
| `dcache` | integrated D-cache and tag/data/refill/store/control specs, design specs, verification plans, verification reports |
| `tile` | core/frontend/cache integration spec, design spec, verification plan, verification report |
| `wdg` | AHB watchdog spec, design spec, verification plan, verification report |
| `i2c` | AHB I2C master spec, design spec, verification plan, verification report |
| `wasp1` | SoC top spec, design spec, verification plan, verification report |
| `ftdi_debugger` | external FTDI debugger spec, pinout, Rev A detailed design spec and editable diagram, verification plan/report, static collateral checker, and OpenOCD reference config |

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
core/docs/core_trap_spec.md
core/docs/core_hazard_spec.md
core/docs/core_wb_spec.md
core/docs/core_debug_ctrl_spec.md
core/docs/core_pipe_spec.md
core/docs/core_int_datapath_spec.md
debug/docs/debug_dmi_if_spec.md
debug/docs/debug_dmi_regs_spec.md
debug/docs/debug_halt_ctrl_spec.md
debug/docs/debug_reg_access_spec.md
debug/docs/debug_abstract_cmd_spec.md
frontend/docs/frontend_spec.md
frontend/docs/frontend_pc_spec.md
frontend/docs/frontend_fetch_spec.md
frontend/docs/frontend_ibuf_spec.md
icache/docs/icache_spec.md
icache/docs/icache_tag_spec.md
icache/docs/icache_data_spec.md
icache/docs/icache_refill_spec.md
icache/docs/icache_ctrl_spec.md
dcache/docs/dcache_spec.md
dcache/docs/dcache_tag_spec.md
dcache/docs/dcache_data_spec.md
dcache/docs/dcache_refill_spec.md
dcache/docs/dcache_store_spec.md
dcache/docs/dcache_ctrl_spec.md
tile/docs/tile_spec.md
wdg/docs/ahb_wdg_spec.md
i2c/docs/ahb_i2c_spec.md
wasp1/docs/wasp1_spec.md
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
core/docs/core_trap_design_spec.md
core/docs/core_hazard_design_spec.md
core/docs/core_wb_design_spec.md
core/docs/core_debug_ctrl_design_spec.md
core/docs/core_pipe_design_spec.md
core/docs/core_int_datapath_design_spec.md
debug/docs/debug_dmi_if_design_spec.md
debug/docs/debug_dmi_regs_design_spec.md
debug/docs/debug_halt_ctrl_design_spec.md
debug/docs/debug_reg_access_design_spec.md
debug/docs/debug_abstract_cmd_design_spec.md
frontend/docs/frontend_design_spec.md
frontend/docs/frontend_pc_design_spec.md
frontend/docs/frontend_fetch_design_spec.md
frontend/docs/frontend_ibuf_design_spec.md
icache/docs/icache_design_spec.md
icache/docs/icache_tag_design_spec.md
icache/docs/icache_data_design_spec.md
icache/docs/icache_refill_design_spec.md
icache/docs/icache_ctrl_design_spec.md
dcache/docs/dcache_design_spec.md
dcache/docs/dcache_tag_design_spec.md
dcache/docs/dcache_data_design_spec.md
dcache/docs/dcache_refill_design_spec.md
dcache/docs/dcache_store_design_spec.md
dcache/docs/dcache_ctrl_design_spec.md
tile/docs/tile_design_spec.md
wdg/docs/ahb_wdg_design_spec.md
i2c/docs/ahb_i2c_design_spec.md
wasp1/docs/wasp1_design_spec.md
```

## Project Status

See the root-level `ROADMAP.md` for current progress and next steps.

## Presentation Decks

Detailed design presentation decks live beside their module documents under
`<module>/docs/wasp1_*_design.pptx`. Current decks cover common, bus, SRAM,
OTP, timer, GPIO, UART, DMA, INTC, core, frontend, I-cache, D-cache, tile,
debug, watchdog, I2C, and the `wasp1` SoC top.
