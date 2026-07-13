MODULE := ftdi_debugger
PYTHON ?= python3
DIAGRAM := docs/diagrams/ftdi_debugger_revA_block.graffle
KICAD_CLI ?= /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli
KICAD_DIR := hw/kicad/wasp1_ft2232h_debugger_revA
KICAD_ROOT := $(KICAD_DIR)/wasp1_ft2232h_debugger_revA.kicad_sch
KICAD_SVG_DIR := hw/schematic/svg
KICAD_ERC_REPORT := logs/ftdi_debugger_revA_erc.rpt

.PHONY: all lint check diagram-check kicad-generate kicad-erc kicad-svg clean

all: lint

lint: check diagram-check

check:
	$(PYTHON) sw/check_ftdi_debugger_collateral.py

diagram-check:
	$(PYTHON) ../docs/tools/audit_graffle_diagram.py $(DIAGRAM)

kicad-generate:
	PYTHONPATH=$${PYTHONPATH:-} $(PYTHON) sw/generate_ftdi_debugger_kicad.py --output $(KICAD_DIR)

kicad-erc:
	@mkdir -p logs
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) sch erc \
		--output $(KICAD_ERC_REPORT) --format report --severity-all \
		--exit-code-violations $(KICAD_ROOT)

kicad-svg:
	@mkdir -p $(KICAD_SVG_DIR)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) sch export svg \
		--no-background-color --output $(KICAD_SVG_DIR) $(KICAD_ROOT)
	$(PYTHON) sw/fix_kicad_svg_background.py $(KICAD_SVG_DIR)/*.svg

clean:
	@true
