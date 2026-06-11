MODULE := sram
VERILATOR ?= verilator
RTL_FILELIST := filelists/sram.f
TB_AHB_SRAM_FILELIST := filelists/tb_ahb_sram.f
AHB_SRAM_TOP := tb_ahb_sram

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_sram \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-sram

sim-ahb-sram:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_SRAM_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_SRAM_TOP) \
		-f $(TB_AHB_SRAM_FILELIST) > logs/tb_ahb_sram_build.log 2>&1
	@./build/obj_$(AHB_SRAM_TOP)/V$(AHB_SRAM_TOP) > logs/tb_ahb_sram.log 2>&1
	@cat logs/tb_ahb_sram.log

clean:
	@rm -rf build/* logs/* wave/*
