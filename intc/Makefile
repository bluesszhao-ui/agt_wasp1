MODULE := intc
VERILATOR ?= verilator
RTL_FILELIST := filelists/intc.f
TB_AHB_INTC_FILELIST := filelists/tb_ahb_intc.f
AHB_INTC_TOP := tb_ahb_intc

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_intc \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-intc

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_intc \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_intc \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-ahb-intc:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_INTC_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_INTC_TOP) \
		-f $(TB_AHB_INTC_FILELIST) > logs/tb_ahb_intc_build.log 2>&1
	@./build/obj_$(AHB_INTC_TOP)/V$(AHB_INTC_TOP) > logs/tb_ahb_intc.log 2>&1
	@cat logs/tb_ahb_intc.log

clean:
	@rm -rf build/* logs/* wave/*
