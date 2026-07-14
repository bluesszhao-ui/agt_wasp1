MODULE := ftdi_debugger
PYTHON ?= python3
DIAGRAM := docs/diagrams/ftdi_debugger_revA_block.graffle
KICAD_CLI ?= /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli
KICAD_DIR := hw/kicad/wasp1_ft2232h_debugger_revA
KICAD_ROOT := $(KICAD_DIR)/wasp1_ft2232h_debugger_revA.kicad_sch
KICAD_BOARD := $(KICAD_DIR)/wasp1_ft2232h_debugger_revA.kicad_pcb
KICAD_NETLIST := build/wasp1_ft2232h_debugger_revA.xml
KICAD_PLACEMENT_DIR := build/placement/wasp1_ft2232h_debugger_revA
KICAD_PLACEMENT_BOARD := $(KICAD_PLACEMENT_DIR)/wasp1_ft2232h_debugger_revA.kicad_pcb
KICAD_PLACEMENT_PROJECT := $(KICAD_PLACEMENT_DIR)/wasp1_ft2232h_debugger_revA.kicad_pro
KICAD_PCB_DRC_REPORT := logs/ftdi_debugger_revA_pcb_placement_drc.rpt
KICAD_PCB_FINAL_DRC_REPORT := logs/ftdi_debugger_revA_pcb_final_drc.rpt
KICAD_PCB_RENDER := build/ftdi_debugger_revA_top.png
KICAD_MFG_DIR := build/manufacturing
KICAD_GERBER_DIR := $(KICAD_MFG_DIR)/gerber
KICAD_DRILL_DIR := $(KICAD_MFG_DIR)/drill
KICAD_POSITIONS := $(KICAD_MFG_DIR)/wasp1_ft2232h_debugger_revA_positions.csv
KICAD_IPCD356 := $(KICAD_MFG_DIR)/wasp1_ft2232h_debugger_revA.ipc
KICAD_BOARD_STATS := $(KICAD_MFG_DIR)/wasp1_ft2232h_debugger_revA_board_stats.json
KICAD_FOOTPRINT_ROOT ?= /Applications/KiCad/KiCad.app/Contents/SharedSupport/footprints
KICAD_PYTHONPATH ?= build/python
KICAD_PYTHON ?= /Applications/KiCad/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3
KICAD_SVG_DIR := hw/schematic/svg
KICAD_ERC_REPORT := logs/ftdi_debugger_revA_erc.rpt

.PHONY: all lint check diagram-check host-lint host-test kicad-generate kicad-erc kicad-svg \
	kicad-netlist kicad-pcb-generate kicad-pcb-placement-drc \
	kicad-pcb-final-drc kicad-pcb-manufacturing kicad-pcb-render \
	kicad-python-deps clean

all: lint host-test

lint: check diagram-check host-lint

check:
	$(PYTHON) sw/check_ftdi_debugger_collateral.py

diagram-check:
	$(PYTHON) ../docs/tools/audit_graffle_diagram.py $(DIAGRAM)

host-lint:
	$(PYTHON) -m compileall -q host

host-test:
	PYTHONPATH=host $(PYTHON) -m unittest discover -s host/tests -v

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
	@mkdir -p $(KICAD_PLACEMENT_DIR)
	cp $(KICAD_DIR)/*.kicad_sch $(KICAD_DIR)/*.kicad_sym \
		$(KICAD_DIR)/*.kicad_pro $(KICAD_DIR)/*.kicad_dru \
		$(KICAD_DIR)/*-lib-table $(KICAD_PLACEMENT_DIR)/
	PYTHONPATH=$(KICAD_PYTHONPATH):$${PYTHONPATH:-} $(PYTHON) sw/generate_ftdi_debugger_pcb.py \
		--netlist $(KICAD_NETLIST) --footprint-root $(KICAD_FOOTPRINT_ROOT) \
		--output $(KICAD_PLACEMENT_BOARD) --project $(KICAD_PLACEMENT_PROJECT)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb upgrade --force $(KICAD_PLACEMENT_BOARD)

kicad-pcb-placement-drc: kicad-pcb-generate
	@mkdir -p logs
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb drc \
		--output $(KICAD_PCB_DRC_REPORT) --format report --units mm \
		--severity-all --all-track-errors --schematic-parity $(KICAD_PLACEMENT_BOARD)
	$(PYTHON) sw/check_pcb_placement_drc.py $(KICAD_PCB_DRC_REPORT)

kicad-pcb-final-drc:
	@mkdir -p logs
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb drc \
		--output $(KICAD_PCB_FINAL_DRC_REPORT) --format report --units mm \
		--severity-all --all-track-errors --schematic-parity $(KICAD_BOARD)
	$(KICAD_PYTHON) sw/check_routed_pcb.py $(KICAD_BOARD) $(KICAD_PCB_FINAL_DRC_REPORT)

kicad-pcb-manufacturing: kicad-pcb-final-drc
	@mkdir -p $(KICAD_GERBER_DIR) $(KICAD_DRILL_DIR)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb export gerbers \
		--output $(KICAD_GERBER_DIR)/ --precision 6 --no-protel-ext \
		--subtract-soldermask --check-zones \
		--layers F.Cu,In1.Cu,In2.Cu,B.Cu,F.Mask,B.Mask,F.Silkscreen,B.Silkscreen,Edge.Cuts \
		$(KICAD_BOARD)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb export drill \
		--output $(KICAD_DRILL_DIR)/ --format excellon --excellon-units mm \
		--excellon-zeros-format decimal --excellon-oval-format route \
		--excellon-separate-th --generate-map --map-format svg --generate-report \
		--report-path $(KICAD_MFG_DIR)/wasp1_ft2232h_debugger_revA_drill_report.txt \
		$(KICAD_BOARD)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb export pos \
		--output $(KICAD_POSITIONS) --format csv --units mm --side both \
		--exclude-dnp $(KICAD_BOARD)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb export ipcd356 \
		--output $(KICAD_IPCD356) $(KICAD_BOARD)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb export stats \
		--output $(KICAD_BOARD_STATS) --format json --units mm $(KICAD_BOARD)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb export pdf \
		--output $(KICAD_MFG_DIR)/wasp1_ft2232h_debugger_revA_top_assembly.pdf \
		--mode-single --layers F.Fab,F.Silkscreen,Edge.Cuts \
		--sketch-pads-on-fab-layers --crossout-DNP-footprints-on-fab-layers \
		--exclude-value --no-property-popups --scale 0 --black-and-white \
		--check-zones $(KICAD_BOARD)
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb export pdf \
		--output $(KICAD_MFG_DIR)/wasp1_ft2232h_debugger_revA_bottom_assembly.pdf \
		--mode-single --layers B.Fab,B.Silkscreen,Edge.Cuts --mirror \
		--sketch-pads-on-fab-layers --crossout-DNP-footprints-on-fab-layers \
		--exclude-value --no-property-popups --scale 0 --black-and-white \
		--check-zones $(KICAD_BOARD)
	$(PYTHON) sw/check_manufacturing_outputs.py $(KICAD_MFG_DIR)

kicad-pcb-render:
	@mkdir -p build
	XDG_CACHE_HOME=/tmp/wasp1_font_cache $(KICAD_CLI) pcb render \
		--output $(KICAD_PCB_RENDER) --width 1600 --height 1000 \
		--side top --perspective --quality basic $(KICAD_BOARD)

clean:
	@true
