MODULE := debug
VERILATOR ?= verilator
DEBUG_RTL_FILELIST := filelists/debug.f
DEBUG_TB_FILELIST := filelists/tb_debug.f
DEBUG_TB_TOP := tb_debug
DMI_RTL_FILELIST := filelists/debug_dmi_regs.f
DMI_TB_FILELIST := filelists/tb_debug_dmi_regs.f
DMI_TB_TOP := tb_debug_dmi_regs
HALT_CTRL_RTL_FILELIST := filelists/debug_halt_ctrl.f
HALT_CTRL_TB_FILELIST := filelists/tb_debug_halt_ctrl.f
HALT_CTRL_TB_TOP := tb_debug_halt_ctrl
REG_ACCESS_RTL_FILELIST := filelists/debug_reg_access.f
REG_ACCESS_TB_FILELIST := filelists/tb_debug_reg_access.f
REG_ACCESS_TB_TOP := tb_debug_reg_access
ABSTRACT_CMD_RTL_FILELIST := filelists/debug_abstract_cmd.f
ABSTRACT_CMD_TB_FILELIST := filelists/tb_debug_abstract_cmd.f
ABSTRACT_CMD_TB_TOP := tb_debug_abstract_cmd
JTAG_DTM_RTL_FILELIST := filelists/debug_jtag_dtm.f
JTAG_DTM_TB_FILELIST := filelists/tb_debug_jtag_dtm.f
JTAG_DTM_TB_TOP := tb_debug_jtag_dtm
JTAG_RTL_FILELIST := filelists/debug_jtag.f
JTAG_TB_FILELIST := filelists/tb_debug_jtag.f
JTAG_TB_TOP := tb_debug_jtag

.PHONY: all lint lint-top lint-dmi-regs lint-halt-ctrl lint-reg-access lint-abstract-cmd \
	lint-jtag-dtm lint-jtag \
	lint-ic lint-top-ic lint-dmi-regs-ic lint-halt-ctrl-ic lint-reg-access-ic lint-abstract-cmd-ic \
	lint-jtag-dtm-ic lint-jtag-ic \
	lint-fpga-v7 lint-dmi-regs-fpga-v7 lint-halt-ctrl-fpga-v7 \
	lint-reg-access-fpga-v7 lint-abstract-cmd-fpga-v7 lint-top-fpga-v7 \
	lint-jtag-dtm-fpga-v7 lint-jtag-fpga-v7 \
	sim sim-top sim-dmi-regs sim-halt-ctrl sim-reg-access sim-abstract-cmd sim-jtag-dtm sim-jtag clean

all: lint sim

lint: lint-top lint-dmi-regs lint-halt-ctrl lint-reg-access lint-abstract-cmd lint-jtag-dtm lint-jtag

lint-top:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(DEBUG_RTL_FILELIST) > logs/lint_top.log 2>&1
	@cat logs/lint_top.log

lint-dmi-regs:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_dmi_regs \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(DMI_RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

lint-halt-ctrl:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_halt_ctrl \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(HALT_CTRL_RTL_FILELIST) > logs/lint_halt_ctrl.log 2>&1
	@cat logs/lint_halt_ctrl.log

lint-reg-access:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_reg_access \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(REG_ACCESS_RTL_FILELIST) > logs/lint_reg_access.log 2>&1
	@cat logs/lint_reg_access.log

lint-abstract-cmd:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_abstract_cmd \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(ABSTRACT_CMD_RTL_FILELIST) > logs/lint_abstract_cmd.log 2>&1
	@cat logs/lint_abstract_cmd.log

lint-jtag-dtm:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_jtag_dtm \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-UNDRIVEN -f $(JTAG_DTM_RTL_FILELIST) > logs/lint_jtag_dtm.log 2>&1
	@cat logs/lint_jtag_dtm.log

lint-jtag:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_jtag \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-UNDRIVEN -f $(JTAG_RTL_FILELIST) > logs/lint_jtag.log 2>&1
	@cat logs/lint_jtag.log

lint-ic: lint-top-ic lint-dmi-regs-ic lint-halt-ctrl-ic lint-reg-access-ic lint-abstract-cmd-ic \
	lint-jtag-dtm-ic lint-jtag-ic

lint-top-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(DEBUG_RTL_FILELIST) > logs/lint_top_ic.log 2>&1
	@cat logs/lint_top_ic.log

lint-dmi-regs-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_dmi_regs \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(DMI_RTL_FILELIST) > logs/lint_ic.log 2>&1
	@cat logs/lint_ic.log

lint-halt-ctrl-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_halt_ctrl \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(HALT_CTRL_RTL_FILELIST) > logs/lint_halt_ctrl_ic.log 2>&1
	@cat logs/lint_halt_ctrl_ic.log

lint-reg-access-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_reg_access \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(REG_ACCESS_RTL_FILELIST) > logs/lint_reg_access_ic.log 2>&1
	@cat logs/lint_reg_access_ic.log

lint-abstract-cmd-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_abstract_cmd \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(ABSTRACT_CMD_RTL_FILELIST) > logs/lint_abstract_cmd_ic.log 2>&1
	@cat logs/lint_abstract_cmd_ic.log

lint-jtag-dtm-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_jtag_dtm \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-UNDRIVEN -f $(JTAG_DTM_RTL_FILELIST) > logs/lint_jtag_dtm_ic.log 2>&1
	@cat logs/lint_jtag_dtm_ic.log

lint-jtag-ic:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_jtag \
		+define+WASP1_TARGET_IC \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-UNDRIVEN -f $(JTAG_RTL_FILELIST) > logs/lint_jtag_ic.log 2>&1
	@cat logs/lint_jtag_ic.log

lint-fpga-v7: lint-dmi-regs-fpga-v7 lint-halt-ctrl-fpga-v7 \
	lint-reg-access-fpga-v7 lint-abstract-cmd-fpga-v7 lint-top-fpga-v7 \
	lint-jtag-dtm-fpga-v7 lint-jtag-fpga-v7

lint-top-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(DEBUG_RTL_FILELIST) > logs/lint_top_fpga_v7.log 2>&1
	@cat logs/lint_top_fpga_v7.log

lint-dmi-regs-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_dmi_regs \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(DMI_RTL_FILELIST) > logs/lint_fpga_v7.log 2>&1
	@cat logs/lint_fpga_v7.log

lint-halt-ctrl-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_halt_ctrl \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(HALT_CTRL_RTL_FILELIST) > logs/lint_halt_ctrl_fpga_v7.log 2>&1
	@cat logs/lint_halt_ctrl_fpga_v7.log

lint-reg-access-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_reg_access \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN \
		-f $(REG_ACCESS_RTL_FILELIST) > logs/lint_reg_access_fpga_v7.log 2>&1
	@cat logs/lint_reg_access_fpga_v7.log

lint-abstract-cmd-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_abstract_cmd \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(ABSTRACT_CMD_RTL_FILELIST) > logs/lint_abstract_cmd_fpga_v7.log 2>&1
	@cat logs/lint_abstract_cmd_fpga_v7.log

lint-jtag-dtm-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_jtag_dtm \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-UNDRIVEN -f $(JTAG_DTM_RTL_FILELIST) > logs/lint_jtag_dtm_fpga_v7.log 2>&1
	@cat logs/lint_jtag_dtm_fpga_v7.log

lint-jtag-fpga-v7:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module debug_jtag \
		+define+WASP1_TARGET_FPGA_XILINX_VIRTEX7 \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Wno-UNDRIVEN -f $(JTAG_RTL_FILELIST) > logs/lint_jtag_fpga_v7.log 2>&1
	@cat logs/lint_jtag_fpga_v7.log

sim: sim-top sim-dmi-regs sim-halt-ctrl sim-reg-access sim-abstract-cmd sim-jtag-dtm sim-jtag

sim-top:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DEBUG_TB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DEBUG_TB_TOP) -f $(DEBUG_TB_FILELIST) \
		> logs/tb_debug_build.log 2>&1
	@./build/obj_$(DEBUG_TB_TOP)/V$(DEBUG_TB_TOP) > logs/tb_debug.log 2>&1
	@cat logs/tb_debug.log

sim-dmi-regs:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DMI_TB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DMI_TB_TOP) -f $(DMI_TB_FILELIST) \
		> logs/tb_debug_dmi_regs_build.log 2>&1
	@./build/obj_$(DMI_TB_TOP)/V$(DMI_TB_TOP) > logs/tb_debug_dmi_regs.log 2>&1
	@cat logs/tb_debug_dmi_regs.log

sim-halt-ctrl:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(HALT_CTRL_TB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(HALT_CTRL_TB_TOP) -f $(HALT_CTRL_TB_FILELIST) \
		> logs/tb_debug_halt_ctrl_build.log 2>&1
	@./build/obj_$(HALT_CTRL_TB_TOP)/V$(HALT_CTRL_TB_TOP) \
		> logs/tb_debug_halt_ctrl.log 2>&1
	@cat logs/tb_debug_halt_ctrl.log

sim-reg-access:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(REG_ACCESS_TB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(REG_ACCESS_TB_TOP) -f $(REG_ACCESS_TB_FILELIST) \
		> logs/tb_debug_reg_access_build.log 2>&1
	@./build/obj_$(REG_ACCESS_TB_TOP)/V$(REG_ACCESS_TB_TOP) \
		> logs/tb_debug_reg_access.log 2>&1
	@cat logs/tb_debug_reg_access.log

sim-abstract-cmd:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(ABSTRACT_CMD_TB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(ABSTRACT_CMD_TB_TOP) -f $(ABSTRACT_CMD_TB_FILELIST) \
		> logs/tb_debug_abstract_cmd_build.log 2>&1
	@./build/obj_$(ABSTRACT_CMD_TB_TOP)/V$(ABSTRACT_CMD_TB_TOP) \
		> logs/tb_debug_abstract_cmd.log 2>&1
	@cat logs/tb_debug_abstract_cmd.log

sim-jtag-dtm:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(JTAG_DTM_TB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(JTAG_DTM_TB_TOP) -f $(JTAG_DTM_TB_FILELIST) \
		> logs/tb_debug_jtag_dtm_build.log 2>&1
	@./build/obj_$(JTAG_DTM_TB_TOP)/V$(JTAG_DTM_TB_TOP) \
		> logs/tb_debug_jtag_dtm.log 2>&1
	@cat logs/tb_debug_jtag_dtm.log

sim-jtag:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(JTAG_TB_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(JTAG_TB_TOP) -f $(JTAG_TB_FILELIST) \
		> logs/tb_debug_jtag_build.log 2>&1
	@./build/obj_$(JTAG_TB_TOP)/V$(JTAG_TB_TOP) \
		> logs/tb_debug_jtag.log 2>&1
	@cat logs/tb_debug_jtag.log

clean:
	@rm -rf build/* logs/* wave/*
