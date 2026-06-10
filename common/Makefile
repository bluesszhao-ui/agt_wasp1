MODULE := common
VERILATOR ?= verilator
FILELIST := filelists/common.f
TOP := common_lint_top

.PHONY: all lint sim clean

all: lint

lint:
	@mkdir -p build logs
	$(VERILATOR) --lint-only -sv --top-module $(TOP) \
		-Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-UNUSEDPARAM \
		-f $(FILELIST) > logs/lint.log 2>&1
	@cat logs/lint.log

sim:
	@echo "$(MODULE): testbench is not implemented yet."

clean:
	@rm -rf build/* logs/* wave/*
