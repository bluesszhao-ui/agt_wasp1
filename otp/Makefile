MODULE := otp
VERILATOR ?= verilator
RTL_FILELIST := filelists/otp.f
TB_AHB_OTP_FILELIST := filelists/tb_ahb_otp.f
AHB_OTP_TOP := tb_ahb_otp

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_otp \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-ahb-otp

lint-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_otp \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_otp \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-f $(RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

sim-ahb-otp:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(AHB_OTP_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNSIGNED \
		-Mdir build/obj_$(AHB_OTP_TOP) \
		-f $(TB_AHB_OTP_FILELIST) > logs/tb_ahb_otp_build.log 2>&1
	@./build/obj_$(AHB_OTP_TOP)/V$(AHB_OTP_TOP) > logs/tb_ahb_otp.log 2>&1
	@cat logs/tb_ahb_otp.log

clean:
	@rm -rf build/* logs/* wave/*
