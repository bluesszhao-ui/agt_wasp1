MODULE := core
VERILATOR ?= verilator
RTL_FILELIST := filelists/core.f
TB_CORE_ALU_FILELIST := filelists/tb_core_alu.f
TB_CORE_REGFILE_FILELIST := filelists/tb_core_regfile.f
TB_CORE_DECODE_FILELIST := filelists/tb_core_decode.f
TB_CORE_BRANCH_FILELIST := filelists/tb_core_branch.f
TB_CORE_CSR_FILELIST := filelists/tb_core_csr.f
TB_CORE_LSU_FILELIST := filelists/tb_core_lsu.f
CORE_ALU_TOP := tb_core_alu
CORE_REGFILE_TOP := tb_core_regfile
CORE_DECODE_TOP := tb_core_decode
CORE_BRANCH_TOP := tb_core_branch
CORE_CSR_TOP := tb_core_csr
CORE_LSU_TOP := tb_core_lsu

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module core_alu \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_regfile \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_decode \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_branch \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_csr \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_lsu \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-core-alu sim-core-regfile sim-core-decode sim-core-branch sim-core-csr sim-core-lsu

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module core_alu \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_regfile \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_decode \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_branch \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_csr \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_lsu \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module core_alu \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_regfile \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_decode \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_branch \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_csr \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module core_lsu \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-core-alu:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(CORE_ALU_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(CORE_ALU_TOP) \
		-f $(TB_CORE_ALU_FILELIST) > logs/tb_core_alu_build.log 2>&1
	@./build/obj_$(CORE_ALU_TOP)/V$(CORE_ALU_TOP) > logs/tb_core_alu.log 2>&1
	@cat logs/tb_core_alu.log

sim-core-regfile:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(CORE_REGFILE_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(CORE_REGFILE_TOP) \
		-f $(TB_CORE_REGFILE_FILELIST) > logs/tb_core_regfile_build.log 2>&1
	@./build/obj_$(CORE_REGFILE_TOP)/V$(CORE_REGFILE_TOP) > logs/tb_core_regfile.log 2>&1
	@cat logs/tb_core_regfile.log

sim-core-decode:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(CORE_DECODE_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(CORE_DECODE_TOP) \
		-f $(TB_CORE_DECODE_FILELIST) > logs/tb_core_decode_build.log 2>&1
	@./build/obj_$(CORE_DECODE_TOP)/V$(CORE_DECODE_TOP) > logs/tb_core_decode.log 2>&1
	@cat logs/tb_core_decode.log

sim-core-branch:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(CORE_BRANCH_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(CORE_BRANCH_TOP) \
		-f $(TB_CORE_BRANCH_FILELIST) > logs/tb_core_branch_build.log 2>&1
	@./build/obj_$(CORE_BRANCH_TOP)/V$(CORE_BRANCH_TOP) > logs/tb_core_branch.log 2>&1
	@cat logs/tb_core_branch.log

sim-core-csr:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(CORE_CSR_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(CORE_CSR_TOP) \
		-f $(TB_CORE_CSR_FILELIST) > logs/tb_core_csr_build.log 2>&1
	@./build/obj_$(CORE_CSR_TOP)/V$(CORE_CSR_TOP) > logs/tb_core_csr.log 2>&1
	@cat logs/tb_core_csr.log

sim-core-lsu:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(CORE_LSU_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(CORE_LSU_TOP) \
		-f $(TB_CORE_LSU_FILELIST) > logs/tb_core_lsu_build.log 2>&1
	@./build/obj_$(CORE_LSU_TOP)/V$(CORE_LSU_TOP) > logs/tb_core_lsu.log 2>&1
	@cat logs/tb_core_lsu.log

clean:
	@rm -rf build/* logs/* wave/*
