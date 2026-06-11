MODULE := timer
VERILATOR ?= verilator
RTL_FILELIST := filelists/timer.f
TB_AHB_TIMER_FILELIST := filelists/tb_ahb_timer.f
AHB_TIMER_TOP := tb_ahb_timer

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_timer \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-timer

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_timer \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_timer \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-ahb-timer:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_TIMER_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_TIMER_TOP) \
		-f $(TB_AHB_TIMER_FILELIST) > logs/tb_ahb_timer_build.log 2>&1
	@./build/obj_$(AHB_TIMER_TOP)/V$(AHB_TIMER_TOP) > logs/tb_ahb_timer.log 2>&1
	@cat logs/tb_ahb_timer.log

clean:
	@rm -rf build/* logs/* wave/*
