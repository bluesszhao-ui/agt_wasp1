# wasp1 Module Hierarchy

## 1. First-Level Modules

```text
common
wasp1
tile
core
frontend
icache
dcache
bus
otp
sram
dma
debug
timer
intc
wdg
uart
i2c
gpio
llvm_s1
```

## 2. Directory Template

Each first-level hardware module uses this structure:

```text
module_name/
  rtl/
  tb/
  filelists/
  build/
  logs/
  dc/
  dv/
  sw/
  wave/
  docs/
  Makefile
```

`llvm_s1` uses a compiler/BSP-oriented structure instead of the hardware IP
template.

## 3. Hardware Module Breakdown

### common

```text
common
  wasp1_pkg
  ahb_lite_if
  mem_req_rsp_if
  irq_if
  debug_if
  reset_sync
  sync_reg
  simple_fifo
  skid_buffer
```

### wasp1

```text
wasp1
  wasp1_top
  wasp1_reset_ctrl
  wasp1_clk_ctrl
  wasp1_addr_map
  wasp1_irq_connect
  wasp1_debug_connect
```

### tile

```text
tile
  tile
  tile_core_bus_arb
  tile_irq_router
  tile_debug_router

Instances:
  frontend
  core
  icache
  dcache
```

### core

```text
core
  core
  core_pipe
  core_decode
  core_regfile
  core_alu
  core_branch
  core_lsu
  core_csr
  core_trap
  core_hazard
  core_wb
```

### frontend

```text
frontend
  frontend
  frontend_pc
  frontend_fetch
  frontend_redirect
  frontend_ibuf
```

### icache

```text
icache
  icache
  icache_tag
  icache_data
  icache_ctrl
  icache_refill
  icache_uncached
```

### dcache

```text
dcache
  dcache
  dcache_tag
  dcache_data
  dcache_ctrl
  dcache_refill
  dcache_storebuf
  dcache_uncached
```

### bus

```text
bus
  ahb_arbiter_2m
  ahb_decoder
  ahb_slave_mux
  ahb_default_slave
  ahb_reg_slice
  ahb_to_reg_if
```

### otp

```text
otp
  otp
  otp_ahb_slave
  otp_regs
  otp_array
  otp_read_path
  otp_prog_fsm
  otp_lock
  otp_init_model
```

### sram

```text
sram
  ahb_sram
  sram_byte_en
  sram_model
  sram_preload
```

### dma

```text
dma
  dma
  dma_regs
  dma_ctrl
  dma_ahb_master
  dma_irq
```

### debug

```text
debug
  debug
  debug_jtag
  debug_jtag_dtm
  riscv_dm
  debug_rom
  debug_halt_ctrl
  debug_reg_access
  debug_mem_access
  debug_abstract_cmd
  debug_progbuf
  debug_progbuf_exec
```

### timer

```text
timer
  timer
  timer_ahb_slave
  timer_regs
  timer_counter
  timer_cmp
```

### intc

```text
intc
  intc
  intc_ahb_slave
  intc_gateway
  intc_pending
  intc_enable
  intc_priority
  intc_claim_complete
```

### wdg

```text
wdg
  wdg
  wdg_ahb_slave
  wdg_regs
  wdg_counter
  wdg_reset_irq
```

### uart

```text
uart
  uart
  uart_ahb_slave
  uart_regs
  uart_baud
  uart_tx
  uart_rx
  uart_fifo
  uart_irq
```

### i2c

```text
i2c
  i2c
  i2c_ahb_slave
  i2c_regs
  i2c_master
  i2c_bit_ctrl
  i2c_irq
```

### gpio

```text
gpio
  gpio
  gpio_ahb_slave
  gpio_regs
  gpio_data
  gpio_dir
  gpio_irq
```

## 4. llvm_s1 Structure

```text
llvm_s1
  toolchain
    llvm-project
    build
    install
    patches
    configs
    docs
  bsp
    include
    startup
    linker
    bootloader
    runtime
    examples
  scripts
  tests
    compile
    runtime
    abi
    linker
  docs
  build
  logs
  Makefile
```
