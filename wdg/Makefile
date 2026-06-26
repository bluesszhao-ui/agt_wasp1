MODULE := wdg
VERILATOR ?= verilator
RTL_FILELIST := filelists/wdg.f
TB_AHB_WDG_FILELIST := filelists/tb_ahb_wdg.f
AHB_WDG_TOP := tb_ahb_wdg

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_wdg \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-wdg

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_wdg \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_wdg \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-ahb-wdg:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_WDG_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_WDG_TOP) \
		-f $(TB_AHB_WDG_FILELIST) > logs/tb_ahb_wdg_build.log 2>&1
	@./build/obj_$(AHB_WDG_TOP)/V$(AHB_WDG_TOP) > logs/tb_ahb_wdg.log 2>&1
	@cat logs/tb_ahb_wdg.log

clean:
	@rm -rf build/* logs/* wave/*
