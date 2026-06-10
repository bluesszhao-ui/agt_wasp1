MODULE := bus
VERILATOR ?= verilator
RTL_FILELIST := filelists/bus.f
TB_DECODER_FILELIST := filelists/tb_ahb_decoder.f
DECODER_TOP := tb_ahb_decoder

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module ahb_decoder \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-f $(RTL_FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim: sim-decoder

sim-decoder:
	@mkdir -p build logs
	$(VERILATOR) -sv --binary --timing --top-module $(DECODER_TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
		-Mdir build/obj_$(DECODER_TOP) \
		-f $(TB_DECODER_FILELIST) > logs/tb_ahb_decoder_build.log 2>&1
	@./build/obj_$(DECODER_TOP)/V$(DECODER_TOP) > logs/tb_ahb_decoder.log 2>&1
	@cat logs/tb_ahb_decoder.log

clean:
	@rm -rf build/* logs/* wave/*
