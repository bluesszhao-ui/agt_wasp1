MODULE := frontend
VERILATOR ?= verilator
RTL_FILELIST := filelists/frontend.f
TB_FRONTEND_PC_FILELIST := filelists/tb_frontend_pc.f
FRONTEND_PC_TOP := tb_frontend_pc

.PHONY: all lint lint-ic lint-fpga-v7 sim sim-frontend-pc clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module frontend_pc \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module frontend_pc \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module frontend_pc \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim: sim-frontend-pc

sim-frontend-pc:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(FRONTEND_PC_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(FRONTEND_PC_TOP) \
		-f $(TB_FRONTEND_PC_FILELIST) > logs/tb_frontend_pc_build.log 2>&1
	@./build/obj_$(FRONTEND_PC_TOP)/V$(FRONTEND_PC_TOP) > logs/tb_frontend_pc.log 2>&1
	@cat logs/tb_frontend_pc.log

clean:
	@rm -rf build/* logs/* wave/*
