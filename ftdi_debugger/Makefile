MODULE := ftdi_debugger
PYTHON ?= python3
DIAGRAM := docs/diagrams/ftdi_debugger_revA_block.graffle

.PHONY: all lint check diagram-check clean

all: lint

lint: check diagram-check

check:
	$(PYTHON) sw/check_ftdi_debugger_collateral.py

diagram-check:
	$(PYTHON) ../docs/tools/audit_graffle_diagram.py $(DIAGRAM)

clean:
	@true
