MODULE := ftdi_debugger
PYTHON ?= python3
DIAGRAM := docs/diagrams/ftdi_debugger_revA_block.graffle
KICAD_CLI ?= /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli
KICAD_DIR := hw/kicad/wasp1_ft2232h_debugger_revA
KICAD_ROOT := $(KICAD_DIR)/wasp1_ft2232h_debugger_revA.kicad_sch
KICAD_BOARD := $(KICAD_DIR)/wasp1_ft2232h_debugger_revA.kicad_pcb
KICAD_NETLIST := build/wasp1_ft2232h_debugger_revA.xml
KICAD_PCB_DRC_REPORT := logs/ftdi_debugger_revA_pcb_placement_drc.rpt
KICAD_PCB_RENDER := build/ftdi_debugger_revA_top.png
KICAD_FOOTPRINT_ROOT ?= /Applications/KiCad/KiCad.app/Contents/SharedSupport/footprints
KICAD_PYTHONPATH ?= build/python
KICAD_SVG_DIR := hw/schematic/svg
KICAD_ERC_REPORT := logs/ftdi_debugger_revA_erc.rpt

.PHONY: all lint check diagram-check kicad-generate kicad-erc kicad-svg \
	kicad-netlist kicad-pcb-generate kicad-pcb-placement-drc \
	kicad-pcb-render kicad-python-deps clean

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

kicad-netlist:
	@mkdir -p build
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) sch export netlist \
		--format kicadxml --output $(KICAD_NETLIST) $(KICAD_ROOT)

kicad-python-deps:
	@test -f $(KICAD_PYTHONPATH)/kiutils/__init__.py || \
		$(PYTHON) -m pip install --target $(KICAD_PYTHONPATH) -r sw/requirements-kicad.txt

kicad-pcb-generate: kicad-python-deps kicad-netlist
	PYTHONPATH=$(KICAD_PYTHONPATH):$${PYTHONPATH:-} $(PYTHON) sw/generate_ftdi_debugger_pcb.py \
		--netlist $(KICAD_NETLIST) --footprint-root $(KICAD_FOOTPRINT_ROOT) \
		--output $(KICAD_BOARD) --project $(KICAD_DIR)/wasp1_ft2232h_debugger_revA.kicad_pro
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb upgrade --force $(KICAD_BOARD)

kicad-pcb-placement-drc:
	@mkdir -p logs
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb drc \
		--output $(KICAD_PCB_DRC_REPORT) --format report --units mm \
		--severity-all --all-track-errors --schematic-parity $(KICAD_BOARD)
	$(PYTHON) sw/check_pcb_placement_drc.py $(KICAD_PCB_DRC_REPORT)

kicad-pcb-render:
	@mkdir -p build
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb render \
		--output $(KICAD_PCB_RENDER) --width 1600 --height 1000 \
		--side top --perspective --quality basic $(KICAD_BOARD)

clean:
	@true
