MODULE := ftdi_debugger
PYTHON ?= python3

.PHONY: all lint check clean

all: lint

lint: check

check:
	$(PYTHON) sw/check_ftdi_debugger_collateral.py

clean:
	@true
