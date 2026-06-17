MODULE := icache
VERILATOR ?= verilator
RTL_FILELIST := filelists/icache.f
TB_ICACHE_TAG_FILELIST := filelists/tb_icache_tag.f
TB_ICACHE_DATA_FILELIST := filelists/tb_icache_data.f
TB_ICACHE_REFILL_FILELIST := filelists/tb_icache_refill.f
TB_ICACHE_CTRL_FILELIST := filelists/tb_icache_ctrl.f
ICACHE_TAG_TOP := tb_icache_tag
ICACHE_DATA_TOP := tb_icache_data
ICACHE_REFILL_TOP := tb_icache_refill
ICACHE_CTRL_TOP := tb_icache_ctrl

.PHONY: all lint lint-ic lint-fpga-v7 sim sim-icache-tag sim-icache-data sim-icache-refill sim-icache-ctrl clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module icache_tag \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_data \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_refill \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_ctrl \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	@cat logs/lint.log

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module icache_tag \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_data \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_refill \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_ctrl \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module icache_tag \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_data \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_refill \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module icache_ctrl \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim: sim-icache-tag sim-icache-data sim-icache-refill sim-icache-ctrl

sim-icache-tag:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(ICACHE_TAG_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(ICACHE_TAG_TOP) \
		-f $(TB_ICACHE_TAG_FILELIST) > logs/tb_icache_tag_build.log 2>&1
	@./build/obj_$(ICACHE_TAG_TOP)/V$(ICACHE_TAG_TOP) > logs/tb_icache_tag.log 2>&1
	@cat logs/tb_icache_tag.log

sim-icache-data:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(ICACHE_DATA_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(ICACHE_DATA_TOP) \
		-f $(TB_ICACHE_DATA_FILELIST) > logs/tb_icache_data_build.log 2>&1
	@./build/obj_$(ICACHE_DATA_TOP)/V$(ICACHE_DATA_TOP) > logs/tb_icache_data.log 2>&1
	@cat logs/tb_icache_data.log

sim-icache-refill:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(ICACHE_REFILL_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(ICACHE_REFILL_TOP) \
		-f $(TB_ICACHE_REFILL_FILELIST) > logs/tb_icache_refill_build.log 2>&1
	@./build/obj_$(ICACHE_REFILL_TOP)/V$(ICACHE_REFILL_TOP) > logs/tb_icache_refill.log 2>&1
	@cat logs/tb_icache_refill.log

sim-icache-ctrl:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(ICACHE_CTRL_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(ICACHE_CTRL_TOP) \
		-f $(TB_ICACHE_CTRL_FILELIST) > logs/tb_icache_ctrl_build.log 2>&1
	@./build/obj_$(ICACHE_CTRL_TOP)/V$(ICACHE_CTRL_TOP) > logs/tb_icache_ctrl.log 2>&1
	@cat logs/tb_icache_ctrl.log

clean:
	@rm -rf build/* logs/* wave/*
