MODULE := llvm_s1

CHECK_SCRIPT := scripts/check_bsp.sh
CHECK_LOG := logs/check_bsp.log
SMOKE_SCRIPT := scripts/run_smoke_tests.sh
SMOKE_LOG := logs/smoke_tests.log
BUILD_TOOLCHAIN_SCRIPT := scripts/build_local_llvm.sh
OTP_IMAGE_CHECK_SCRIPT := scripts/check_otp_image.sh
OTP_IMAGE_CHECK_LOG := logs/check_otp_image.log

.PHONY: all toolchain build-toolchain bsp smoke otp-image test check-files clean

all: test

toolchain:
	@$(SMOKE_SCRIPT) --toolchain-only $(SMOKE_LOG)

build-toolchain:
	@$(BUILD_TOOLCHAIN_SCRIPT)

bsp: check-files

smoke: check-files
	@$(SMOKE_SCRIPT) $(SMOKE_LOG)

otp-image:
	@$(OTP_IMAGE_CHECK_SCRIPT) $(OTP_IMAGE_CHECK_LOG)

test: smoke otp-image

check-files:
	@$(CHECK_SCRIPT) $(CHECK_LOG)

clean:
	@rm -rf build/* logs/*
