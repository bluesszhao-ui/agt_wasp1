MODULE := llvm_s1

CHECK_SCRIPT := scripts/check_bsp.sh
CHECK_LOG := logs/check_bsp.log

.PHONY: all toolchain bsp test check-files clean

all: bsp

toolchain:
	@echo "$(MODULE): LLVM build flow is planned but not implemented in stage 1."

bsp: check-files

test: check-files

check-files:
	@$(CHECK_SCRIPT) $(CHECK_LOG)

clean:
	@rm -rf build/* logs/*
