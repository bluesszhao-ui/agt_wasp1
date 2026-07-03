MODULE := wasp1
VERILATOR ?= verilator
RTL_FILELIST := filelists/wasp1.f
TB_WASP1_FILELIST := filelists/tb_wasp1.f
WASP1_TOP := tb_wasp1
OTP_HEX ?= ../llvm_s1/build/smoke/hello_uart_otp.hex

.PHONY: all lint sim sim-sw clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module wasp1 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-wasp1

sim-sw: sim-wasp1-sw

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module wasp1 \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module wasp1 \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-wasp1:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) > logs/tb_wasp1.log 2>&1
	@cat logs/tb_wasp1.log

sim-wasp1-sw:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(WASP1_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(WASP1_TOP) \
		-f $(TB_WASP1_FILELIST) > logs/tb_wasp1_sw_build.log 2>&1
	@./build/obj_$(WASP1_TOP)/V$(WASP1_TOP) +WASP1_OTP_HEX=$(OTP_HEX) > logs/tb_wasp1_sw.log 2>&1
	@cat logs/tb_wasp1_sw.log

clean:
	@rm -rf build/* logs/* wave/*
