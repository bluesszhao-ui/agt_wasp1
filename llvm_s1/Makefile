MODULE := llvm_s1

CHECK_SCRIPT := scripts/check_bsp.sh
CHECK_LOG := logs/check_bsp.log
SMOKE_SCRIPT := scripts/run_smoke_tests.sh
SMOKE_LOG := logs/smoke_tests.log
BUILD_TOOLCHAIN_SCRIPT := scripts/build_local_llvm.sh

.PHONY: all toolchain build-toolchain bsp smoke test check-files clean

all: test

toolchain:
	@$(SMOKE_SCRIPT) --toolchain-only $(SMOKE_LOG)

build-toolchain:
	@$(BUILD_TOOLCHAIN_SCRIPT)

bsp: check-files

smoke: check-files
	@$(SMOKE_SCRIPT) $(SMOKE_LOG)

test: smoke

check-files:
	@$(CHECK_SCRIPT) $(CHECK_LOG)

clean:
	@rm -rf build/* logs/*
