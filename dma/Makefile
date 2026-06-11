MODULE := dma
VERILATOR ?= verilator
RTL_FILELIST := filelists/dma.f
TB_AHB_DMA_FILELIST := filelists/tb_ahb_dma.f
AHB_DMA_TOP := tb_ahb_dma

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_dma \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-dma

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_dma \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_dma \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-ahb-dma:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_DMA_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_DMA_TOP) \
		-f $(TB_AHB_DMA_FILELIST) > logs/tb_ahb_dma_build.log 2>&1
	@./build/obj_$(AHB_DMA_TOP)/V$(AHB_DMA_TOP) > logs/tb_ahb_dma.log 2>&1
	@cat logs/tb_ahb_dma.log

clean:
	@rm -rf build/* logs/* wave/*
