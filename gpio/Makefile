MODULE := gpio
VERILATOR ?= verilator
RTL_FILELIST := filelists/gpio.f
TB_AHB_GPIO_FILELIST := filelists/tb_ahb_gpio.f
AHB_GPIO_TOP := tb_ahb_gpio

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_gpio \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-gpio

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_gpio \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_gpio \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-ahb-gpio:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_GPIO_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_GPIO_TOP) \
		-f $(TB_AHB_GPIO_FILELIST) > logs/tb_ahb_gpio_build.log 2>&1
	@./build/obj_$(AHB_GPIO_TOP)/V$(AHB_GPIO_TOP) > logs/tb_ahb_gpio.log 2>&1
	@cat logs/tb_ahb_gpio.log

clean:
	@rm -rf build/* logs/* wave/*
