MODULE := wasp1
VERILATOR ?= verilator
RTL_FILELIST := filelists/wasp1.f
TB_WASP1_FILELIST := filelists/tb_wasp1.f
WASP1_TOP := tb_wasp1
OTP_HEX ?= ../llvm_s1/build/smoke/hello_uart_otp.hex
GDB_OTP_HEX ?= dv/gdb/wasp1_debug_step_otp.hex
OTP_PROGRAM_HEX ?= ../llvm_s1/build/smoke/otp_program_otp.hex
DMA_COPY_HEX ?= ../llvm_s1/build/smoke/dma_copy_otp.hex
DMA_IRQ_HEX ?= ../llvm_s1/build/smoke/dma_irq_otp.hex
GPIO_IRQ_HEX ?= ../llvm_s1/build/smoke/gpio_irq_otp.hex
UART_IRQ_HEX ?= ../llvm_s1/build/smoke/uart_irq_otp.hex
UART_RX_IRQ_HEX ?= ../llvm_s1/build/smoke/uart_rx_irq_otp.hex
LONG_BOOT_HEX ?= ../llvm_s1/build/smoke/long_boot_otp.hex
MIXED_IRQ_DMA_HEX ?= ../llvm_s1/build/smoke/mixed_irq_dma_otp.hex
TIMER_IRQ_HEX ?= ../llvm_s1/build/smoke/timer_irq_otp.hex
SYSTEM_STRESS_HEX ?= ../llvm_s1/build/smoke/system_stress_otp.hex
SIM_ARGS ?=
RBB_TOP := wasp1
RBB_OBJ_DIR := build/obj_wasp1_rbb
RBB_PORT ?= 9824

.PHONY: all lint sim sim-sw sim-otp-program sim-dma-copy sim-dma-irq sim-gpio-irq sim-uart-irq sim-uart-rx-irq sim-long-boot sim-mixed-irq-dma sim-system-stress sim-timer-irq sim-cache-metrics synth-collateral-check sim-rbb-build sim-rbb-smoke sim-openocd-gdb-smoke sim-openocd-gdb-stress clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module wasp1 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-wasp1

sim-sw: sim-wasp1-sw

sim-otp-program:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_otp_program_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(OTP_PROGRAM_HEX) \
		+WASP1_OTP_PROGRAM_CHECK $(SIM_ARGS) > logs/tb_wasp1_otp_program.log 2>&1
	@cat logs/tb_wasp1_otp_program.log

sim-dma-copy:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_dma_copy_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(DMA_COPY_HEX) \
		+WASP1_DMA_COPY_CHECK $(SIM_ARGS) > logs/tb_wasp1_dma_copy.log 2>&1
	@cat logs/tb_wasp1_dma_copy.log

sim-dma-irq:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_dma_irq_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(DMA_IRQ_HEX) \
		+WASP1_DMA_IRQ_CHECK $(SIM_ARGS) > logs/tb_wasp1_dma_irq.log 2>&1
	@cat logs/tb_wasp1_dma_irq.log

sim-gpio-irq:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_gpio_irq_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(GPIO_IRQ_HEX) \
		+WASP1_GPIO_IRQ_CHECK $(SIM_ARGS) > logs/tb_wasp1_gpio_irq.log 2>&1
	@cat logs/tb_wasp1_gpio_irq.log

sim-uart-irq:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_uart_irq_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(UART_IRQ_HEX) \
		+WASP1_UART_IRQ_CHECK $(SIM_ARGS) > logs/tb_wasp1_uart_irq.log 2>&1
	@cat logs/tb_wasp1_uart_irq.log

sim-uart-rx-irq:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_uart_rx_irq_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(UART_RX_IRQ_HEX) \
		+WASP1_UART_RX_IRQ_CHECK $(SIM_ARGS) > logs/tb_wasp1_uart_rx_irq.log 2>&1
	@cat logs/tb_wasp1_uart_rx_irq.log

sim-long-boot:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_long_boot_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(LONG_BOOT_HEX) \
		+WASP1_LONG_BOOT_CHECK $(SIM_ARGS) > logs/tb_wasp1_long_boot.log 2>&1
	@cat logs/tb_wasp1_long_boot.log

sim-mixed-irq-dma:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_mixed_irq_dma_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(MIXED_IRQ_DMA_HEX) \
		+WASP1_MIXED_IRQ_DMA_CHECK $(SIM_ARGS) > logs/tb_wasp1_mixed_irq_dma.log 2>&1
	@cat logs/tb_wasp1_mixed_irq_dma.log

sim-system-stress:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_system_stress_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(SYSTEM_STRESS_HEX) \
		+WASP1_SYSTEM_STRESS_CHECK $(SIM_ARGS) > logs/tb_wasp1_system_stress.log 2>&1
	@cat logs/tb_wasp1_system_stress.log

sim-timer-irq:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_timer_irq_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(TIMER_IRQ_HEX) \
		+WASP1_TIMER_IRQ_CHECK $(SIM_ARGS) > logs/tb_wasp1_timer_irq.log 2>&1
	@cat logs/tb_wasp1_timer_irq.log

sim-cache-metrics:
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP)_metrics \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_cache_metrics_build.log 2>&1
	python3 dv/wasp1_cache_metrics.py \
		--sim build/obj_$(WASP1_TOP)_metrics/V$(WASP1_TOP) \
		--logs-dir logs \
		--csv logs/cache_metrics.csv \
		--markdown logs/cache_metrics.md > logs/cache_metrics.log 2>&1
	@cat logs/cache_metrics.log

synth-collateral-check:
	@mkdir -p logs
	python3 dv/check_synth_collateral.py > logs/synth_collateral_check.log 2>&1
	@cat logs/synth_collateral_check.log

sim-rbb-build:
	@mkdir -p build logs
	$(VERILATOR) -sv --cc --exe --build --timing --top-module $(RBB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir $(RBB_OBJ_DIR) -f $(RTL_FILELIST) \
		dv/wasp1_remote_bitbang_main.cpp > logs/sim_rbb_build.log 2>&1
	@cat logs/sim_rbb_build.log

sim-rbb-smoke: sim-rbb-build
	@mkdir -p logs
	python3 dv/wasp1_rbb_smoke.py --sim $(RBB_OBJ_DIR)/V$(RBB_TOP) \
		--port $(RBB_PORT) > logs/sim_rbb_smoke.log 2>&1
	@cat logs/sim_rbb_smoke.log

sim-openocd-gdb-smoke: sim-rbb-build
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p logs
	python3 dv/wasp1_openocd_gdb_smoke.py \
		--sim $(RBB_OBJ_DIR)/V$(RBB_TOP) \
		--openocd-cfg dv/openocd/wasp1_remote_bitbang.cfg \
		--gdb-script dv/gdb/wasp1_debug_smoke.gdb \
		--otp-hex $(GDB_OTP_HEX) \
		--rbb-port $(RBB_PORT) > logs/sim_openocd_gdb_smoke.log 2>&1
	@cat logs/sim_openocd_gdb_smoke.log

sim-openocd-gdb-stress: sim-rbb-build
	$(MAKE) -C ../llvm_s1 smoke
	@mkdir -p logs
	python3 dv/wasp1_openocd_gdb_smoke.py \
		--sim $(RBB_OBJ_DIR)/V$(RBB_TOP) \
		--openocd-cfg dv/openocd/wasp1_remote_bitbang.cfg \
		--gdb-script dv/gdb/wasp1_debug_stress.gdb \
		--otp-hex $(GDB_OTP_HEX) \
		--rbb-port $(RBB_PORT) \
		--log-prefix sim_openocd_gdb_stress \
		--pass-label wasp1_openocd_gdb_stress \
		--expect-token wasp1_gdb_reg_write_read_pass \
		--expect-token wasp1_gdb_stress_stepi_pass \
		--expect-token wasp1_gdb_stress_hbreak0_pass \
		--expect-token wasp1_gdb_stress_hbreak4_pass \
		> logs/sim_openocd_gdb_stress.log 2>&1
	@cat logs/sim_openocd_gdb_stress.log

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module wasp1 \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module wasp1 \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-wasp1:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) $(SIM_ARGS) > logs/tb_wasp1.log 2>&1
	@cat logs/tb_wasp1.log

sim-wasp1-sw:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_sw_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(OTP_HEX) $(SIM_ARGS) > logs/tb_wasp1_sw.log 2>&1
	@cat logs/tb_wasp1_sw.log

clean:
	@rm -rf build/* logs/* wave/*
