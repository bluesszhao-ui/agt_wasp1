MODULE := i2c
VERILATOR ?= verilator
RTL_FILELIST := filelists/i2c.f
TB_AHB_I2C_FILELIST := filelists/tb_ahb_i2c.f
AHB_I2C_TOP := tb_ahb_i2c

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_i2c \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-i2c

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_i2c \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_i2c \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-ahb-i2c:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_I2C_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_I2C_TOP) \
		-f $(TB_AHB_I2C_FILELIST) > logs/tb_ahb_i2c_build.log 2>&1
	@./build/obj_$(AHB_I2C_TOP)/V$(AHB_I2C_TOP) > logs/tb_ahb_i2c.log 2>&1
	@cat logs/tb_ahb_i2c.log

clean:
	@rm -rf build/* logs/* wave/*
