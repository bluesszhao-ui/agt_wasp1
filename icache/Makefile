MODULE := icache
VERILATOR ?= verilator
RTL_FILELIST := filelists/icache.f
TB_ICACHE_TAG_FILELIST := filelists/tb_icache_tag.f
ICACHE_TAG_TOP := tb_icache_tag

.PHONY: all lint lint-ic lint-fpga-v7 sim sim-icache-tag clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module icache_tag \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module icache_tag \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module icache_tag \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim: sim-icache-tag

sim-icache-tag:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(ICACHE_TAG_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(ICACHE_TAG_TOP) \
		-f $(TB_ICACHE_TAG_FILELIST) > logs/tb_icache_tag_build.log 2>&1
	@./build/obj_$(ICACHE_TAG_TOP)/V$(ICACHE_TAG_TOP) > logs/tb_icache_tag.log 2>&1
	@cat logs/tb_icache_tag.log

clean:
	@rm -rf build/* logs/* wave/*
