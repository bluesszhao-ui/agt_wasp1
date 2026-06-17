MODULE := dcache
VERILATOR ?= verilator
RTL_FILELIST := filelists/dcache.f
TB_DCACHE_TAG_FILELIST := filelists/tb_dcache_tag.f
TB_DCACHE_DATA_FILELIST := filelists/tb_dcache_data.f
TB_DCACHE_REFILL_FILELIST := filelists/tb_dcache_refill.f
TB_DCACHE_STORE_FILELIST := filelists/tb_dcache_store.f
TB_DCACHE_CTRL_FILELIST := filelists/tb_dcache_ctrl.f
DCACHE_TAG_TOP := tb_dcache_tag
DCACHE_DATA_TOP := tb_dcache_data
DCACHE_REFILL_TOP := tb_dcache_refill
DCACHE_STORE_TOP := tb_dcache_store
DCACHE_CTRL_TOP := tb_dcache_ctrl

.PHONY: all lint lint-ic lint-fpga-v7 sim sim-dcache-tag sim-dcache-data sim-dcache-refill sim-dcache-store sim-dcache-ctrl clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module dcache_tag \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_data \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_refill \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_store \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_ctrl \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint.log 2>&1
	@cat logs/lint.log

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module dcache_tag \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_data \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_refill \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_store \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_ctrl \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module dcache_tag \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_data \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_refill \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_store \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	$(VERILATOR) --lint-only -sv --top-module dcache_ctrl \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) >> logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim: sim-dcache-tag sim-dcache-data sim-dcache-refill sim-dcache-store sim-dcache-ctrl

sim-dcache-tag:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DCACHE_TAG_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DCACHE_TAG_TOP) \
		-f $(TB_DCACHE_TAG_FILELIST) > logs/tb_dcache_tag_build.log 2>&1
	@./build/obj_$(DCACHE_TAG_TOP)/V$(DCACHE_TAG_TOP) > logs/tb_dcache_tag.log 2>&1
	@cat logs/tb_dcache_tag.log

sim-dcache-data:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DCACHE_DATA_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DCACHE_DATA_TOP) \
		-f $(TB_DCACHE_DATA_FILELIST) > logs/tb_dcache_data_build.log 2>&1
	@./build/obj_$(DCACHE_DATA_TOP)/V$(DCACHE_DATA_TOP) > logs/tb_dcache_data.log 2>&1
	@cat logs/tb_dcache_data.log

sim-dcache-refill:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DCACHE_REFILL_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DCACHE_REFILL_TOP) \
		-f $(TB_DCACHE_REFILL_FILELIST) > logs/tb_dcache_refill_build.log 2>&1
	@./build/obj_$(DCACHE_REFILL_TOP)/V$(DCACHE_REFILL_TOP) > logs/tb_dcache_refill.log 2>&1
	@cat logs/tb_dcache_refill.log

sim-dcache-store:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DCACHE_STORE_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DCACHE_STORE_TOP) \
		-f $(TB_DCACHE_STORE_FILELIST) > logs/tb_dcache_store_build.log 2>&1
	@./build/obj_$(DCACHE_STORE_TOP)/V$(DCACHE_STORE_TOP) > logs/tb_dcache_store.log 2>&1
	@cat logs/tb_dcache_store.log

sim-dcache-ctrl:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DCACHE_CTRL_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DCACHE_CTRL_TOP) \
		-f $(TB_DCACHE_CTRL_FILELIST) > logs/tb_dcache_ctrl_build.log 2>&1
	@./build/obj_$(DCACHE_CTRL_TOP)/V$(DCACHE_CTRL_TOP) > logs/tb_dcache_ctrl.log 2>&1
	@cat logs/tb_dcache_ctrl.log

clean:
	@rm -rf build/* logs/* wave/*
