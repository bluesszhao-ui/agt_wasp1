#!/usr/bin/env python3
"""Generate the placed four-layer Rev A PCB from a KiCad XML netlist.

The schematic-exported XML remains the connectivity authority. This generator
loads the exact KiCad system footprints named by that netlist, assigns every
pad to its schematic net, and applies a deterministic placement that follows
the USB-to-target signal flow.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
from pathlib import Path
import json
import uuid
import xml.etree.ElementTree as ET

from kiutils.board import Board
from kiutils.footprint import Footprint
from kiutils.items.brditems import LayerToken, Stackup, StackupLayer
from kiutils.items.common import Effects, Font, Net, PageSettings, Position, TitleBlock
from kiutils.items.gritems import GrLine, GrText


BOARD_LEFT = 15.0
BOARD_TOP = 20.0
BOARD_RIGHT = 125.0
BOARD_BOTTOM = 85.0


def stable_uuid(name: str) -> str:
    """Return a deterministic UUID so regenerated board diffs stay useful."""
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"wasp1-ftdi-pcb:{name}"))


def placement_table() -> dict[str, tuple[float, float, float]]:
    """Define the reviewed Rev A functional placement in millimetres."""
    table: dict[str, tuple[float, float, float]] = {
        "J1": (20, 50, 90), "ESD1": (30, 50, 0), "F1": (27, 30, 0),
        "U6": (38, 30, 0), "CBULK1": (31, 35, 0), "CBULK2": (43, 35, 0),
        "RCC1": (24, 61, 0), "RCC2": (29, 61, 0), "RLED1": (35, 25, 0),
        "D1": (40, 25, 0), "U1": (55, 51, 0), "Y1": (55, 34, 0),
        "U2": (67, 34, 0), "RREF": (46, 39, 0), "RRESET": (46, 35, 0),
        "REECS": (69, 40, 0), "CCORE": (65, 48, 0),
        "U3": (76, 29, 0), "U7": (84, 29, 0), "U4": (82, 50, 0),
        "U5": (94, 50, 0), "RREF_TOP": (74, 35, 0), "RREF_BOT": (74, 39, 0),
        "RVALID": (80, 35, 0), "RTARGET_EN": (80, 39, 0), "ROE": (86, 35, 0),
        "RU4_A7": (87, 62, 0), "RU4_A8": (92, 62, 0), "Q1": (75, 68, 0),
        "RLED2": (81, 68, 0), "D2": (87, 68, 0), "ESD2": (105, 50, 0),
        "J2": (117, 50, 0),
        "RTCK": (98, 37, 0), "RTMS": (98, 42, 0), "RTDI": (98, 47, 0),
        "RTRST": (98, 54, 0), "RSRST": (98, 59, 0), "RURX": (98, 64, 0),
    }
    for ref, position in zip(
        (f"CDEC{index}" for index in range(1, 7)),
        ((48, 44, 0), (52, 42, 0), (57, 42, 0), (62, 44, 0), (63, 53, 0), (62, 58, 0)),
    ):
        table[ref] = position
    for ref, position in zip(
        ("CDEC7", "CDEC8", "CDEC9", "CDEC10"),
        ((78, 45, 0), (86, 45, 0), (92, 45, 0), (92, 55, 0)),
    ):
        table[ref] = position
    for index, x in enumerate((42, 51, 60, 69, 78, 87, 105, 114), start=1):
        table[f"TP{index}"] = (x, 78, 0)
    return table


def parse_netlist(path: Path) -> tuple[list[dict[str, str]], list[dict[str, object]]]:
    """Read component metadata and net-to-pad membership from KiCad XML."""
    root = ET.parse(path).getroot()
    components = []
    for comp in root.find("components").findall("comp"):
        sheet = comp.find("sheetpath").attrib["tstamps"]
        components.append({
            "ref": comp.attrib["ref"],
            "value": comp.findtext("value", default=""),
            "footprint": comp.findtext("footprint", default=""),
            "datasheet": comp.findtext("datasheet", default=""),
            "description": next(
                (field.text or "" for field in comp.findall("./fields/field") if field.attrib.get("name") == "Description"),
                "",
            ),
            "dnp": "true" if comp.find("./property[@name='dnp']") is not None else "false",
            "path": f"{sheet}{comp.findtext('tstamps', default='')}",
        })
    nets = []
    for net in root.find("nets").findall("net"):
        nets.append({
            "code": int(net.attrib["code"]),
            "name": net.attrib["name"],
            "nodes": [(node.attrib["ref"], node.attrib["pin"]) for node in net.findall("node")],
        })
    return components, nets


def set_footprint_text(footprint: Footprint, ref: str, value: str) -> None:
    """Replace library placeholders with the board reference and value."""
    for item in footprint.graphicItems:
        if getattr(item, "type", None) == "reference":
            item.text = ref
        elif getattr(item, "type", None) == "value":
            item.text = value


def add_dnp_attributes(board_path: Path, dnp_refs: set[str]) -> None:
    """Add KiCad's native ``dnp`` token to selected footprint attributes.

    kiutils 1.4.8 can parse the other footprint assembly attributes but does
    not yet model KiCad 10's ``dnp`` token.  This scanner therefore edits only
    complete top-level footprint S-expressions whose Reference property exactly
    matches a schematic DNP reference.  Parenthesis depth, rather than a broad
    text replacement, defines each edit boundary.
    """
    text = board_path.read_text(encoding="utf-8")
    cursor = 0
    chunks: list[str] = []
    patched_refs: set[str] = set()
    while True:
        # kiutils writes top-level board objects with two-space indentation;
        # the subsequent KiCad upgrade converts that indentation to tabs.
        start = text.find("\n  (footprint ", cursor)
        if start < 0:
            chunks.append(text[cursor:])
            break
        chunks.append(text[cursor:start])
        depth = 0
        in_string = False
        escaped = False
        end = start + 1
        for end in range(start + 1, len(text)):
            char = text[end]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
                continue
            if char == '"':
                in_string = True
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    end += 1
                    break
        footprint_text = text[start:end]
        matching_ref = next(
            (ref for ref in dnp_refs if f'(property "Reference" "{ref}"' in footprint_text),
            None,
        )
        if matching_ref is not None:
            attribute_marker = "\n    (attr "
            attribute_start = footprint_text.find(attribute_marker)
            if attribute_start < 0:
                raise ValueError(f"DNP footprint {matching_ref} has no attr expression")
            attribute_end = footprint_text.find(")", attribute_start)
            attribute = footprint_text[attribute_start:attribute_end]
            if " dnp" not in attribute:
                footprint_text = (
                    footprint_text[:attribute_end]
                    + " dnp"
                    + footprint_text[attribute_end:]
                )
            patched_refs.add(matching_ref)
        chunks.append(footprint_text)
        cursor = end
    if patched_refs != dnp_refs:
        raise ValueError(
            f"DNP attribute mismatch: requested={sorted(dnp_refs)}, patched={sorted(patched_refs)}"
        )
    board_path.write_text("".join(chunks), encoding="utf-8")


def add_reference_geometry(
    board_path: Path,
    components: list[dict[str, str]],
    footprint_root: Path,
) -> None:
    """Place readable reference designators clear of their own component pads.

    kiutils 1.4.8 retains property values from current KiCad footprints but not
    their property geometry.  The raw board would consequently place every
    reference at its footprint origin.  Deriving a compact offset from the pad
    envelope gives each designator a deterministic starting position that can
    then be checked by DRC and 3D rendering.
    """
    text = board_path.read_text(encoding="utf-8")
    # Local overrides resolve a handful of dense-placement conflicts found by
    # the placement DRC.  Coordinates remain footprint-local millimetres.
    reference_overrides = {
        "J1": (0.0, -6.0),
        "ESD1": (0.0, -3.5),
        "RRESET": (0.0, 1.35),
        "CDEC5": (3.0, 1.35),
        "RTARGET_EN": (0.0, 1.35),
    }
    for component in components:
        ref = component["ref"]
        library, entry = component["footprint"].split(":", 1)
        footprint = Footprint.from_file(
            str(footprint_root / f"{library}.pretty" / f"{entry}.kicad_mod")
        )
        pad_top = min(
            pad.position.Y - (pad.size.Y / 2.0)
            for pad in footprint.pads
        )
        label_y = round(pad_top - 1.0, 2)
        label_x, label_y = reference_overrides.get(ref, (0.0, label_y))
        font_size = 0.8
        # Keep all reference text horizontal on the finished board, including
        # J1 whose footprint body is rotated to meet the left board edge.
        angle = 0.0
        old = f'(property "Reference" "{ref}")'
        hide_line = '      (hide yes)\n' if ref == "J1" else ""
        new = (
            f'(property "Reference" "{ref}"\n'
            f'      (at {label_x:g} {label_y:g} {angle:g})\n'
            '      (layer "F.SilkS")\n'
            f'{hide_line}'
            '      (effects (font '
            f'(size {font_size:g} {font_size:g}) (thickness 0.1)))\n'
            '    )'
        )
        if text.count(old) != 1:
            raise ValueError(f"expected one unplaced Reference property for {ref}")
        text = text.replace(old, new, 1)
    board_path.write_text(text, encoding="utf-8")


def build_board(netlist: Path, footprint_root: Path) -> Board:
    """Create the board, assign footprints/nets, and apply deterministic placement."""
    components, net_rows = parse_netlist(netlist)
    placements = placement_table()
    component_refs = {component["ref"] for component in components}
    if component_refs != set(placements):
        missing = sorted(component_refs - set(placements))
        stale = sorted(set(placements) - component_refs)
        raise ValueError(f"placement mismatch: missing={missing}, stale={stale}")

    board = Board.create_new()
    board.version = "20240108"
    board.generator = "wasp1_pcb_generator"
    board.general.thickness = 1.6
    board.paper = PageSettings(paperSize="A4")
    board.titleBlock = TitleBlock(
        title="wasp1 FT2232H Debugger Rev A PCB",
        date="2026-07-13",
        revision="Rev A",
        company="wasp1",
        comments={1: "Four-layer USB JTAG/UART debugger"},
    )

    # The inner planes are explicitly declared so the intended four-layer stack
    # is visible in the native board source before routing begins.
    board.layers.insert(1, LayerToken(ordinal=1, name="In1.Cu", type="power"))
    board.layers.insert(2, LayerToken(ordinal=2, name="In2.Cu", type="power"))
    board.setup.stackup = Stackup(
        layers=[
            StackupLayer(name="F.SilkS", type="Top Silk Screen", color="White", thickness=0.01),
            StackupLayer(name="F.Mask", type="Top Solder Mask", color="Green", thickness=0.01),
            StackupLayer(name="F.Cu", type="copper", thickness=0.035),
            StackupLayer(name="dielectric 1", type="prepreg", thickness=0.18, material="FR4", epsilonR=4.2, lossTangent=0.02),
            StackupLayer(name="In1.Cu", type="copper", thickness=0.035),
            StackupLayer(name="dielectric 2", type="core", thickness=1.10, material="FR4", epsilonR=4.2, lossTangent=0.02),
            StackupLayer(name="In2.Cu", type="copper", thickness=0.035),
            StackupLayer(name="dielectric 3", type="prepreg", thickness=0.18, material="FR4", epsilonR=4.2, lossTangent=0.02),
            StackupLayer(name="B.Cu", type="copper", thickness=0.035),
            StackupLayer(name="B.Mask", type="Bottom Solder Mask", color="Green", thickness=0.01),
            StackupLayer(name="B.SilkS", type="Bottom Silk Screen", color="White", thickness=0.01),
        ],
        copperFinish="ENIG",
        dielectricContraints="yes",
    )

    board.nets = [Net(number=0, name="")]
    net_by_name: dict[str, Net] = {"": board.nets[0]}
    node_to_net: dict[tuple[str, str], Net] = {}
    for row in net_rows:
        # KiCad emits synthetic one-pin nets for schematic no-connect markers.
        # PCB pads for those pins must remain netless for schematic parity.
        if row["name"].startswith("unconnected-("):
            continue
        net = Net(number=row["code"], name=row["name"])
        board.nets.append(net)
        net_by_name[row["name"]] = net
        for node in row["nodes"]:
            node_to_net[node] = net

    for component in components:
        ref = component["ref"]
        library, entry = component["footprint"].split(":", 1)
        footprint_file = footprint_root / f"{library}.pretty" / f"{entry}.kicad_mod"
        footprint = deepcopy(Footprint.from_file(str(footprint_file)))
        footprint.libId = component["footprint"]
        footprint.position = Position(*placements[ref])
        footprint.tstamp = stable_uuid(f"footprint:{ref}")
        footprint.path = component["path"]
        footprint.properties.update({
            "Reference": ref,
            "Value": component["value"],
            "Footprint": component["footprint"],
            "Datasheet": component["datasheet"],
            "Description": component["description"],
        })
        # Library-level BOM/position exclusions (notably TestPoint) must not
        # override the schematic symbol's assembly contract.
        footprint.attributes.excludeFromBom = False
        footprint.attributes.excludeFromPosFiles = False
        set_footprint_text(footprint, ref, component["value"])
        for pad_index, pad in enumerate(footprint.pads):
            # Repeated pad numbers and unnumbered mechanical holes are legal;
            # each physical pad still requires its own UUID.
            pad.tstamp = stable_uuid(f"pad:{ref}:{pad_index}:{pad.number}")
            pad.net = node_to_net.get((ref, str(pad.number)))
            # KiCad stores a rotated footprint's pad orientation in the pad's
            # local angle as well as rotating its local position.  Preserve any
            # library pad rotation and add the placement rotation so elongated
            # pads (especially USB-C J1) retain their intended orientation.
            placement_angle = placements[ref][2]
            if placement_angle:
                pad.position.angle = ((pad.position.angle or 0) + placement_angle) % 360
        board.footprints.append(footprint)

    corners = (
        ((BOARD_LEFT, BOARD_TOP), (BOARD_RIGHT, BOARD_TOP)),
        ((BOARD_RIGHT, BOARD_TOP), (BOARD_RIGHT, BOARD_BOTTOM)),
        ((BOARD_RIGHT, BOARD_BOTTOM), (BOARD_LEFT, BOARD_BOTTOM)),
        ((BOARD_LEFT, BOARD_BOTTOM), (BOARD_LEFT, BOARD_TOP)),
    )
    for index, (start, end) in enumerate(corners):
        board.graphicItems.append(GrLine(
            start=Position(*start), end=Position(*end), layer="Edge.Cuts", width=0.1,
            tstamp=stable_uuid(f"edge:{index}"),
        ))
    board.graphicItems.extend([
        GrText(
            text="wasp1 FT2232H DEBUGGER REV A", position=Position(66, 23),
            layer="F.SilkS", effects=Effects(font=Font(width=1.5, height=1.5, thickness=0.25)),
            tstamp=stable_uuid("silk:title"),
        ),
        GrText(
            text="USB JTAG + UART", position=Position(66, 82),
            layer="F.SilkS", effects=Effects(font=Font(width=1.0, height=1.0, thickness=0.18)),
            tstamp=stable_uuid("silk:subtitle"),
        ),
        # J1 is rotated 90 degrees at the board edge.  A board-level designator
        # stays horizontal and visible above the connector's metal shell.
        GrText(
            text="J1", position=Position(25, 43), layer="F.SilkS",
            effects=Effects(font=Font(width=0.8, height=0.8, thickness=0.1)),
            tstamp=stable_uuid("silk:j1-reference"),
        ),
    ])
    return board


def update_project_netclasses(project_path: Path) -> None:
    """Install deterministic board net classes into the KiCad project JSON."""
    project = json.loads(project_path.read_text(encoding="utf-8"))
    classes = [
        {"name": "Default", "clearance": 0.20, "track_width": 0.20, "via_diameter": 0.60, "via_drill": 0.30,
         "diff_pair_width": 0.20, "diff_pair_gap": 0.20},
        {"name": "USB_DIFF", "clearance": 0.20, "track_width": 0.20, "via_diameter": 0.60, "via_drill": 0.30,
         "diff_pair_width": 0.20, "diff_pair_gap": 0.18},
        {"name": "POWER", "clearance": 0.25, "track_width": 0.50, "via_diameter": 0.80, "via_drill": 0.40,
         "diff_pair_width": 0.20, "diff_pair_gap": 0.20},
        {"name": "JTAG", "clearance": 0.20, "track_width": 0.25, "via_diameter": 0.60, "via_drill": 0.30,
         "diff_pair_width": 0.20, "diff_pair_gap": 0.20},
    ]
    defaults = {
        "bus_width": 12, "diff_pair_via_gap": 0.25, "line_style": 0,
        "microvia_diameter": 0.3, "microvia_drill": 0.1,
        "pcb_color": "rgba(0, 0, 0, 0.000)", "priority": 2147483647,
        "schematic_color": "rgba(0, 0, 0, 0.000)", "tuning_profile": "", "wire_width": 6,
    }
    project["net_settings"]["classes"] = [{**defaults, **item} for item in classes]
    project["net_settings"]["netclass_patterns"] = [
        {"netclass": "USB_DIFF", "pattern": "/USB_*"},
        {"netclass": "POWER", "pattern": "/(GND|VCC_3V3|VCORE|VREF|USB_VBUS|VBUS_PROTECTED)"},
        {"netclass": "JTAG", "pattern": "/(FT_A_*|TCK*|TMS*|TDI*|TDO|nTRST|nSRST|NTRST_RAW|NSRST_RAW)"},
    ]
    project_path.write_text(json.dumps(project, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--netlist", type=Path, required=True)
    parser.add_argument("--footprint-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    args = parser.parse_args()
    board = build_board(args.netlist, args.footprint_root)
    board.to_file(str(args.output), encoding="utf-8")
    components, _ = parse_netlist(args.netlist)
    add_reference_geometry(args.output, components, args.footprint_root)
    add_dnp_attributes(
        args.output,
        {component["ref"] for component in components if component["dnp"] == "true"},
    )
    update_project_netclasses(args.project)
    print(f"PASS generated {len(board.footprints)} footprints and {len(board.nets) - 1} nets")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
