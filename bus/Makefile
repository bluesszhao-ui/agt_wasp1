MODULE := bus
VERILATOR ?= verilator
RTL_FILELIST := filelists/bus.f
TB_DECODER_FILELIST := filelists/tb_ahb_decoder.f
TB_DEFAULT_SLAVE_FILELIST := filelists/tb_ahb_default_slave.f
TB_SLAVE_MUX_FILELIST := filelists/tb_ahb_slave_mux.f
TB_ARBITER_FILELIST := filelists/tb_ahb_arbiter_2m.f
DECODER_TOP := tb_ahb_decoder
DEFAULT_SLAVE_TOP := tb_ahb_default_slave
SLAVE_MUX_TOP := tb_ahb_slave_mux
ARBITER_TOP := tb_ahb_arbiter_2m

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_decoder \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-decoder sim-default-slave sim-slave-mux sim-arbiter

sim-decoder:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DECODER_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DECODER_TOP) \
		-f $(TB_DECODER_FILELIST) > logs/tb_ahb_decoder_build.log 2>&1
	@./build/obj_$(DECODER_TOP)/V$(DECODER_TOP) > logs/tb_ahb_decoder.log 2>&1
	@cat logs/tb_ahb_decoder.log

sim-default-slave:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DEFAULT_SLAVE_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DEFAULT_SLAVE_TOP) \
		-f $(TB_DEFAULT_SLAVE_FILELIST) > logs/tb_ahb_default_slave_build.log 2>&1
	@./build/obj_$(DEFAULT_SLAVE_TOP)/V$(DEFAULT_SLAVE_TOP) > logs/tb_ahb_default_slave.log 2>&1
	@cat logs/tb_ahb_default_slave.log

sim-slave-mux:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(SLAVE_MUX_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(SLAVE_MUX_TOP) \
		-f $(TB_SLAVE_MUX_FILELIST) > logs/tb_ahb_slave_mux_build.log 2>&1
	@./build/obj_$(SLAVE_MUX_TOP)/V$(SLAVE_MUX_TOP) > logs/tb_ahb_slave_mux.log 2>&1
	@cat logs/tb_ahb_slave_mux.log

sim-arbiter:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(ARBITER_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(ARBITER_TOP) \
		-f $(TB_ARBITER_FILELIST) > logs/tb_ahb_arbiter_2m_build.log 2>&1
	@./build/obj_$(ARBITER_TOP)/V$(ARBITER_TOP) > logs/tb_ahb_arbiter_2m.log 2>&1
	@cat logs/tb_ahb_arbiter_2m.log

clean:
	@rm -rf build/* logs/* wave/*
