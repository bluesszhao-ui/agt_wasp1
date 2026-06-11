MODULE := uart
VERILATOR ?= verilator
RTL_FILELIST := filelists/uart.f
TB_AHB_UART_FILELIST := filelists/tb_ahb_uart.f
AHB_UART_TOP := tb_ahb_uart

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_uart \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-uart

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_uart \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_uart \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-ahb-uart:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_UART_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_UART_TOP) \
		-f $(TB_AHB_UART_FILELIST) > logs/tb_ahb_uart_build.log 2>&1
	@./build/obj_$(AHB_UART_TOP)/V$(AHB_UART_TOP) > logs/tb_ahb_uart.log 2>&1
	@cat logs/tb_ahb_uart.log

clean:
	@rm -rf build/* logs/* wave/*
