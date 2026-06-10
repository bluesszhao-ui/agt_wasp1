HW_MODULES := common bus sram otp timer gpio uart dma intc core frontend icache dcache tile debug wdg i2c wasp1

.PHONY: all lint sim clean llvm_s1 $(HW_MODULES)

all: lint

lint: $(HW_MODULES)

sim:
	@for module in $(HW_MODULES); do $(MAKE) -C $$module sim; done

clean:
	@for module in $(HW_MODULES); do $(MAKE) -C $$module clean; done
	@$(MAKE) -C llvm_s1 clean

llvm_s1:
	@$(MAKE) -C llvm_s1

$(HW_MODULES):
	@$(MAKE) -C $@ lint
