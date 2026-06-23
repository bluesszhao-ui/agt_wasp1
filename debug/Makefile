MODULE := debug
VERILATOR ?= verilator
RTL_FILELIST := filelists/debug_dmi_regs.f
TB_FILELIST := filelists/tb_debug_dmi_regs.f
TB_TOP := tb_debug_dmi_regs

.PHONY: all lint lint-ic lint-fpga-v7 sim clean

all: lint sim

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_dmi_regs \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_dmi_regs \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_dmi_regs \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(TB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(TB_TOP) -f $(TB_FILELIST) \
		> logs/tb_debug_dmi_regs_build.log 2>&1
	@./build/obj_$(TB_TOP)/V$(TB_TOP) > logs/tb_debug_dmi_regs.log 2>&1
	@cat logs/tb_debug_dmi_regs.log

clean:
	@rm -rf build/* logs/* wave/*
