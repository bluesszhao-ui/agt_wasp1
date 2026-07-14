MODULE := llvm_s1

CHECK_SCRIPT := scripts/check_bsp.sh
CHECK_LOG := logs/check_bsp.log
SMOKE_SCRIPT := scripts/run_smoke_tests.sh
SMOKE_LOG := logs/smoke_tests.log
BUILD_TOOLCHAIN_SCRIPT := scripts/build_local_llvm.sh
OTP_IMAGE_CHECK_SCRIPT := scripts/check_otp_image.sh
OTP_IMAGE_CHECK_LOG := logs/check_otp_image.log
UART_OTP_LOADER_SCRIPT := scripts/build_uart_otp_loader.sh
HOST_CC ?= cc

.PHONY: all toolchain build-toolchain bsp smoke otp-image uart-otp-loader \
	uart-otp-protocol-test test check-files clean

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

uart-otp-loader:
	@$(UART_OTP_LOADER_SCRIPT)

uart-otp-protocol-test:
	@mkdir -p build/uart_otp_loader logs
	$(HOST_CC) -std=c11 -Wall -Wextra -Werror \
		-Ibsp/bootloader \
		bsp/bootloader/wasp1_uart_otp_protocol.c \
		tests/runtime/test_uart_otp_protocol.c \
		-o build/uart_otp_loader/test_uart_otp_protocol
	@./build/uart_otp_loader/test_uart_otp_protocol | \
		tee logs/uart_otp_protocol_test.log

test: smoke otp-image uart-otp-protocol-test uart-otp-loader

check-files:
	@$(CHECK_SCRIPT) $(CHECK_LOG)

clean:
	@rm -rf build/* logs/*
