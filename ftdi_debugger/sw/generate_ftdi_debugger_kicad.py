#!/usr/bin/env python3
"""Generate the native KiCad Rev A schematic for the wasp1 FTDI debugger.

The generator is deliberately data driven: every placed component names each
physical pin and its net.  KiCad then re-saves the generated 2021 S-expression
into the installed native format before ERC and export checks are run.
"""

from __future__ import annotations

import argparse
import copy
import json
import uuid
from pathlib import Path

from kiutils.items.common import Effects, Fill, Font, PageSettings, Position, Property, Stroke, TitleBlock
from kiutils.items.schitems import GlobalLabel, HierarchicalSheet, HierarchicalSheetInstance, NoConnect, SchematicSymbol, SymbolInstance, Text
from kiutils.items.syitems import SyRect
from kiutils.schematic import Schematic
from kiutils.symbol import Symbol, SymbolLib, SymbolPin


NS = uuid.UUID("deef5f2b-d6df-5d17-a269-3afc7a0df56f")
PROJECT = "wasp1_ft2232h_debugger_revA"


def uid(key: str) -> str:
    """Return a stable UUID so regenerated schematics produce useful diffs."""
    return str(uuid.uuid5(NS, key))


def pin(number: str, name: str, electrical: str, side: str) -> tuple[str, str, str, str]:
    """Describe one physical package pin and its schematic side."""
    return (str(number), name, electrical, side)


def make_symbol(name: str, prefix: str, footprint: str, datasheet: str,
                pins: list[tuple[str, str, str, str]]) -> Symbol:
    """Create a compact rectangular project-local symbol with exact pin numbers."""
    symbol = Symbol.create_new(f"wasp1:{name}", prefix, name, footprint, datasheet)
    symbol.pinNames = True
    symbol.pinNamesOffset = 0.508
    left = [item for item in pins if item[3] == "L"]
    right = [item for item in pins if item[3] == "R"]
    height = max(len(left), len(right), 2) * 2.54 + 2.54
    half_h = height / 2
    body_x = 10.16
    unit = Symbol()
    unit.libId = f"{name}_1_1"
    unit.graphicItems.append(
        SyRect(
            start=Position(-body_x, -half_h),
            end=Position(body_x, half_h),
            stroke=Stroke(width=0.254),
            fill=Fill(type="background"),
        )
    )
    for side_items, x, angle in ((left, -12.7, 0), (right, 12.7, 180)):
        start_y = -((len(side_items) - 1) * 2.54) / 2
        for index, (number, pin_name, electrical, _) in enumerate(side_items):
            unit.pins.append(
                SymbolPin(
                    electricalType=electrical,
                    graphicalStyle="line",
                    position=Position(x, start_y + index * 2.54, angle),
                    length=2.54,
                    name=pin_name,
                    number=number,
                )
            )
    symbol.units.append(unit)
    return symbol


def symbol_pins(symbol: Symbol) -> list[SymbolPin]:
    """Return pins from the single drawing unit used by Rev A symbols."""
    return symbol.units[0].pins


def symbol_property(key: str, value: str, x: float, y: float, hide: bool = False) -> Property:
    """Create a placed-symbol property with consistent text styling."""
    return Property(
        key=key,
        value=value,
        id={"Reference": 0, "Value": 1, "Footprint": 2, "Datasheet": 3}.get(key),
        position=Position(x, y, 0),
        effects=Effects(font=Font(width=1.27, height=1.27), hide=hide),
    )


def page(title: str, page_number: int) -> Schematic:
    """Create one A3 schematic page with a title block and engineering note."""
    sch = Schematic.create_new()
    sch.paper = PageSettings(paperSize="A3")
    sch.titleBlock = TitleBlock(
        title=title,
        date="2026-07-12",
        revision="Rev A",
        company="wasp1",
        comments={1: "FT2232H Channel A JTAG / Channel B UART", 2: f"Sheet {page_number} of 5"},
    )
    sch.texts.append(
        Text(
            text="All labels are explicit electrical nets; NC markers identify intentionally unused pins.",
            position=Position(120.65, 20.32, 0),
            effects=Effects(font=Font(width=1.5, height=1.5, bold=True)),
            uuid=uid(f"{title}:note"),
        )
    )
    sch.sheetInstances = []
    sch._placed = []  # Generator-only metadata consumed by the root sheet.
    return sch


def add_symbol(sch: Schematic, symbol: Symbol, ref: str, value: str, x: float, y: float,
               nets: dict[str, str | None], dnp: bool = False, on_board: bool = True) -> None:
    """Place a symbol and attach a global label or NC marker to every physical pin."""
    # KiCad's default schematic connection grid is 50 mil (1.27 mm).
    x = round(x / 1.27) * 1.27
    y = round(y / 1.27) * 1.27
    if not any(item.libId == symbol.libId for item in sch.libSymbols):
        sch.libSymbols.append(copy.deepcopy(symbol))
    instance_uuid = uid(f"{sch.titleBlock.title}:{ref}")
    inst = SchematicSymbol()
    inst.libId = symbol.libId
    inst.position = Position(x, y, 0)
    inst.unit = 1
    inst.inBom = on_board
    inst.onBoard = on_board
    inst.dnp = dnp
    inst.uuid = instance_uuid
    footprint = next(item.value for item in symbol.properties if item.key == "Footprint")
    datasheet = next(item.value for item in symbol.properties if item.key == "Datasheet")
    inst.properties = [
        symbol_property("Reference", ref, x - 10.16, y - 10.16),
        symbol_property("Value", value, x - 10.16, y + 10.16),
        symbol_property("Footprint", footprint, x, y, True),
        symbol_property("Datasheet", datasheet, x, y, True),
    ]
    for item in symbol_pins(symbol):
        pin_uuid = uid(f"{sch.titleBlock.title}:{ref}:pin:{item.number}")
        inst.pins[item.number] = pin_uuid
        px = x + item.position.X
        # Library-symbol Y coordinates point upward; page Y coordinates point downward.
        py = y - item.position.Y
        net = nets.get(item.number)
        if net is None:
            sch.noConnects.append(NoConnect(position=Position(px, py), uuid=uid(f"{ref}:{item.number}:nc")))
        else:
            # Point label text away from the symbol body on both sides.
            angle = 180 if item.position.X < 0 else 0
            sch.globalLabels.append(
                GlobalLabel(
                    text=net,
                    shape="bidirectional" if item.electricalType in ("bidirectional", "tri_state") else "passive",
                    position=Position(px, py, angle),
                    effects=Effects(font=Font(width=1.0, height=1.0)),
                    uuid=uid(f"{sch.titleBlock.title}:{ref}:{item.number}:{net}"),
                )
            )
    sch.schematicSymbols.append(inst)
    sch._placed.append((instance_uuid, ref, value, footprint))


def build_symbols() -> dict[str, Symbol]:
    """Define every physical component used by the Rev A schematic."""
    resistor = make_symbol("R", "R", "Resistor_SMD:R_0402_1005Metric", "", [
        pin("1", "1", "passive", "L"), pin("2", "2", "passive", "R")])
    capacitor = make_symbol("C", "C", "Capacitor_SMD:C_0402_1005Metric", "", [
        pin("1", "+", "passive", "L"), pin("2", "-", "passive", "R")])
    led = make_symbol("LED", "D", "LED_SMD:LED_0603_1608Metric", "", [
        pin("1", "K", "passive", "L"), pin("2", "A", "passive", "R")])
    capacitor_0603 = make_symbol("C_0603", "C", "Capacitor_SMD:C_0603_1608Metric", "", [
        pin("1", "+", "passive", "L"), pin("2", "-", "passive", "R")])
    capacitor_0805 = make_symbol("C_0805", "C", "Capacitor_SMD:C_0805_2012Metric", "", [
        pin("1", "+", "passive", "L"), pin("2", "-", "passive", "R")])
    symbols = {"R": resistor, "C": capacitor, "C0603": capacitor_0603, "C0805": capacitor_0805, "LED": led}
    symbols["PWR_FLAG"] = make_symbol("PWR_FLAG", "#FLG", "", "", [
        pin("1", "PWR_FLAG", "power_out", "R")])
    symbols["GND"] = make_symbol("GND", "#PWR", "", "", [
        pin("1", "GND", "power_in", "R")])
    symbols["GND"].isPower = True
    symbols["GND"].pinNamesHide = True
    symbols["TP"] = make_symbol("TestPoint", "TP", "TestPoint:TestPoint_Pad_D1.0mm", "", [
        pin("1", "TP", "passive", "R")])
    symbols["FUSE"] = make_symbol("MF-MSMF050-2", "F", "Fuse:Fuse_1812_4532Metric", "https://www.bourns.com/docs/product-datasheets/mf-msmf.pdf", [
        pin("1", "IN", "passive", "L"), pin("2", "OUT", "passive", "R")])
    symbols["USB_C"] = make_symbol("USB4105-GF-A", "J", "Connector_USB:USB_C_Receptacle_GCT_USB4105-xx-A_16P_TopMnt_Horizontal", "https://gct.co/connector/usb4105", [
        pin("A1", "GND", "passive", "L"), pin("A4", "VBUS", "passive", "L"), pin("A5", "CC1", "bidirectional", "L"),
        pin("A6", "D+", "bidirectional", "L"), pin("A7", "D-", "bidirectional", "L"), pin("A8", "SBU1", "bidirectional", "L"),
        pin("A9", "VBUS", "passive", "L"), pin("A12", "GND", "passive", "L"), pin("B1", "GND", "passive", "R"),
        pin("B4", "VBUS", "passive", "R"), pin("B5", "CC2", "bidirectional", "R"), pin("B6", "D+", "bidirectional", "R"),
        pin("B7", "D-", "bidirectional", "R"), pin("B8", "SBU2", "bidirectional", "R"), pin("B9", "VBUS", "passive", "R"),
        pin("B12", "GND", "passive", "R"), pin("SH", "SHIELD", "passive", "R")])
    symbols["USB_ESD"] = make_symbol("USBLC6-2SC6", "ESD", "Package_TO_SOT_SMD:SOT-23-6", "https://www.st.com/resource/en/datasheet/usblc6-2.pdf", [
        pin("1", "I/O1", "passive", "L"), pin("2", "GND", "passive", "L"), pin("3", "I/O2", "passive", "L"),
        pin("4", "I/O2", "passive", "R"), pin("5", "VBUS", "passive", "R"), pin("6", "I/O1", "passive", "R")])
    symbols["LDO"] = make_symbol("AP2112K-3.3", "U", "Package_TO_SOT_SMD:SOT-23-5", "https://www.diodes.com/assets/Datasheets/AP2112.pdf", [
        pin("1", "VIN", "power_in", "L"), pin("2", "GND", "power_in", "L"), pin("3", "EN", "input", "L"),
        pin("4", "NC", "no_connect", "R"), pin("5", "VOUT", "power_out", "R")])
    ftdi_pins = [
        pin("1", "GND", "power_in", "L"), pin("2", "OSCI", "input", "L"), pin("3", "OSCO", "output", "L"), pin("4", "VPHY", "power_in", "L"),
        pin("5", "GND", "power_in", "L"), pin("6", "REF", "output", "L"), pin("7", "DM", "bidirectional", "L"), pin("8", "DP", "bidirectional", "L"),
        pin("9", "VPLL", "power_in", "L"), pin("10", "AGND", "power_in", "L"), pin("11", "GND", "power_in", "L"), pin("12", "VCORE", "power_in", "L"),
        pin("13", "TEST", "input", "L"), pin("14", "RESET_N", "input", "L"), pin("15", "GND", "power_in", "L"), pin("16", "ADBUS0", "bidirectional", "L"),
        pin("17", "ADBUS1", "bidirectional", "L"), pin("18", "ADBUS2", "bidirectional", "L"), pin("19", "ADBUS3", "bidirectional", "L"), pin("20", "VCCIOA", "power_in", "L"),
        pin("21", "ADBUS4", "bidirectional", "L"), pin("22", "ADBUS5", "bidirectional", "L"), pin("23", "ADBUS6", "bidirectional", "L"), pin("24", "ADBUS7", "bidirectional", "L"),
        pin("25", "GND", "power_in", "L"), pin("26", "ACBUS0", "bidirectional", "L"), pin("27", "ACBUS1", "bidirectional", "L"), pin("28", "ACBUS2", "bidirectional", "L"),
        pin("29", "ACBUS3", "bidirectional", "L"), pin("30", "ACBUS4", "bidirectional", "L"), pin("31", "VCCIOA", "power_in", "L"), pin("32", "ACBUS5", "bidirectional", "L"),
        pin("33", "ACBUS6", "bidirectional", "R"), pin("34", "ACBUS7", "bidirectional", "R"), pin("35", "GND", "power_in", "R"), pin("36", "SUSPEND_N", "output", "R"),
        pin("37", "VCORE", "power_in", "R"), pin("38", "BDBUS0", "bidirectional", "R"), pin("39", "BDBUS1", "bidirectional", "R"), pin("40", "BDBUS2", "bidirectional", "R"),
        pin("41", "BDBUS3", "bidirectional", "R"), pin("42", "VCCIOB", "power_in", "R"), pin("43", "BDBUS4", "bidirectional", "R"), pin("44", "BDBUS5", "bidirectional", "R"),
        pin("45", "BDBUS6", "bidirectional", "R"), pin("46", "BDBUS7", "bidirectional", "R"), pin("47", "GND", "power_in", "R"), pin("48", "BCBUS0", "bidirectional", "R"),
        pin("49", "VREGOUT", "power_out", "R"), pin("50", "VREGIN", "power_in", "R"), pin("51", "GND", "power_in", "R"), pin("52", "BCBUS1", "bidirectional", "R"),
        pin("53", "BCBUS2", "bidirectional", "R"), pin("54", "BCBUS3", "bidirectional", "R"), pin("55", "BCBUS4", "bidirectional", "R"), pin("56", "VCCIOB", "power_in", "R"),
        pin("57", "BCBUS5", "bidirectional", "R"), pin("58", "BCBUS6", "bidirectional", "R"), pin("59", "BCBUS7", "bidirectional", "R"), pin("60", "PWREN_N", "output", "R"),
        pin("61", "EEDATA", "bidirectional", "R"), pin("62", "EECLK", "output", "R"), pin("63", "EECS", "output", "R"), pin("64", "VCORE", "power_in", "R")]
    symbols["FTDI"] = make_symbol("FT2232HL", "U", "Package_QFP:LQFP-64_10x10mm_P0.5mm", "https://ftdichip.com/wp-content/uploads/2024/01/DS_FT2232H.pdf", ftdi_pins)
    symbols["EEPROM"] = make_symbol("93LC56BT-I-SN", "U", "Package_SO:SOIC-8_3.9x4.9mm_P1.27mm", "https://ww1.microchip.com/downloads/en/DeviceDoc/21794G.pdf", [
        pin("1", "CS", "input", "L"), pin("2", "CLK", "input", "L"), pin("3", "DI", "input", "L"), pin("4", "DO", "tri_state", "L"),
        pin("5", "VSS", "power_in", "R"), pin("6", "NC", "no_connect", "R"), pin("7", "NC", "no_connect", "R"), pin("8", "VCC", "power_in", "R")])
    symbols["OSC"] = make_symbol("ECS-3225MVQ-120-CN-TR", "Y", "Oscillator:Oscillator_SMD_EuroQuartz_XO32-4Pin_3.2x2.5mm", "https://ecsxtal.com/store/pdf/ECS-3225MVQ.pdf", [
        pin("1", "OE", "input", "L"), pin("2", "GND", "power_in", "L"), pin("3", "OUT", "output", "R"), pin("4", "VDD", "power_in", "R")])
    symbols["COMP"] = make_symbol("TLV7041DBVR", "U", "Package_TO_SOT_SMD:SOT-23-5", "https://www.ti.com/lit/ds/symlink/tlv7041.pdf", [
        pin("1", "OUT", "open_collector", "L"), pin("2", "V-", "power_in", "L"), pin("3", "IN+", "input", "L"), pin("4", "IN-", "input", "R"), pin("5", "V+", "power_in", "R")])
    symbols["NAND"] = make_symbol("SN74LVC1G00DBVR", "U", "Package_TO_SOT_SMD:SOT-23-5", "https://www.ti.com/lit/ds/symlink/sn74lvc1g00.pdf", [
        pin("1", "A", "input", "L"), pin("2", "B", "input", "L"), pin("3", "GND", "power_in", "L"), pin("4", "Y", "output", "R"), pin("5", "VCC", "power_in", "R")])
    axc8 = [pin("1", "VCCA", "power_in", "L"), pin("2", "DIR1", "input", "L")]
    axc8 += [pin(str(index + 2), f"A{index}", "bidirectional", "L") for index in range(1, 9)]
    axc8 += [pin("11", "DIR2", "input", "L"), pin("12", "GND", "power_in", "L"), pin("13", "GND", "power_in", "R")]
    axc8 += [pin(str(22 - index), f"B{index}", "bidirectional", "R") for index in range(1, 9)]
    axc8 += [pin("22", "OE_N", "input", "R"), pin("23", "VCCB", "power_in", "R"), pin("24", "VCCB", "power_in", "R")]
    symbols["AXC8"] = make_symbol("SN74AXC8T245PWR", "U", "Package_SO:TSSOP-24_4.4x7.8mm_P0.65mm", "https://www.ti.com/lit/ds/symlink/sn74axc8t245.pdf", axc8)
    symbols["AXC2"] = make_symbol("SN74AXC2T245RSWR", "U", "Package_DFN_QFN:Texas_RSW0010A_UQFN-10_1.4x1.8mm_P0.4mm", "https://www.ti.com/lit/ds/symlink/sn74axc2t245.pdf", [
        pin("1", "DIR2", "input", "L"), pin("2", "OE_N", "input", "L"), pin("3", "GND", "power_in", "L"), pin("4", "B2", "bidirectional", "L"), pin("5", "B1", "bidirectional", "L"),
        pin("6", "VCCB", "power_in", "R"), pin("7", "VCCA", "power_in", "R"), pin("8", "A1", "bidirectional", "R"), pin("9", "A2", "bidirectional", "R"), pin("10", "DIR1", "input", "R")])
    symbols["NMOS"] = make_symbol("2N7002", "Q", "Package_TO_SOT_SMD:SOT-23", "", [
        pin("1", "G", "input", "L"), pin("2", "S", "passive", "L"), pin("3", "D", "passive", "R")])
    symbols["ESD8"] = make_symbol("TPD8E003DQDR", "ESD", "Package_SON:WSON-8-1EP_2x2mm_P0.5mm_EP0.9x1.6mm", "https://www.ti.com/lit/ds/symlink/tpd8e003.pdf", [
        pin("1", "IO1", "passive", "L"), pin("2", "IO2", "passive", "L"), pin("3", "IO3", "passive", "L"), pin("4", "IO4", "passive", "L"),
        pin("5", "IO5", "passive", "R"), pin("6", "IO6", "passive", "R"), pin("7", "IO7", "passive", "R"), pin("8", "IO8", "passive", "R"), pin("9", "GND_PAD", "power_in", "R")])
    j2pins = [pin(str(index), f"PIN{index}", "passive", "L" if index % 2 else "R") for index in range(1, 15)]
    symbols["TARGET"] = make_symbol("WASP1_TARGET_2X7", "J", "Connector_IDC:IDC-Header_2x07_P2.54mm_Vertical", "", j2pins)
    return symbols


def build_pages(symbols: dict[str, Symbol]) -> list[Schematic]:
    """Build the four electrical pages defined by the Rev A design plan."""
    p1 = page("USB and local power", 2)
    add_symbol(p1, symbols["USB_C"], "J1", "USB4105-GF-A", 55, 90, {
        "A1": "GND", "A4": "USB_VBUS", "A5": "CC1", "A6": "USB_DP_CONN", "A7": "USB_DM_CONN", "A8": None,
        "A9": "USB_VBUS", "A12": "GND", "B1": "GND", "B4": "USB_VBUS", "B5": "CC2", "B6": "USB_DP_CONN",
        "B7": "USB_DM_CONN", "B8": None, "B9": "USB_VBUS", "B12": "GND", "SH": "GND"})
    add_symbol(p1, symbols["USB_ESD"], "ESD1", "USBLC6-2SC6", 125, 75, {"1": "USB_DM_CONN", "2": "GND", "3": "USB_DP_CONN", "4": "USB_DP", "5": "USB_VBUS", "6": "USB_DM"})
    add_symbol(p1, symbols["FUSE"], "F1", "MF-MSMF050-2", 125, 115, {"1": "USB_VBUS", "2": "VBUS_PROTECTED"})
    add_symbol(p1, symbols["LDO"], "U6", "AP2112K-3.3", 205, 115, {"1": "VBUS_PROTECTED", "2": "GND", "3": "VBUS_PROTECTED", "4": None, "5": "VCC_3V3"})
    for ref, net, x, y in (("RCC1", "CC1", 55, 160), ("RCC2", "CC2", 95, 160)):
        add_symbol(p1, symbols["R"], ref, "5.1k 1%", x, y, {"1": net, "2": "GND"})
    for ref, value, net, x in (("CBULK1", "4.7u", "VBUS_PROTECTED", 155), ("CBULK2", "4.7u", "VCC_3V3", 205)):
        add_symbol(p1, symbols["C0805"], ref, value, x, 170, {"1": net, "2": "GND"})
    add_symbol(p1, symbols["R"], "RLED1", "2.2k", 275, 100, {"1": "VCC_3V3", "2": "LED_PWR_A"})
    add_symbol(p1, symbols["LED"], "D1", "GREEN", 325, 100, {"1": "GND", "2": "LED_PWR_A"})
    add_symbol(p1, symbols["PWR_FLAG"], "#FLG01", "PWR_FLAG", 275, 150, {"1": "VBUS_PROTECTED"}, on_board=False)
    add_symbol(p1, symbols["PWR_FLAG"], "#FLG02", "PWR_FLAG", 325, 150, {"1": "GND"}, on_board=False)
    add_symbol(p1, symbols["GND"], "#PWR01", "GND", 365, 150, {"1": "GND"}, on_board=False)

    p2 = page("FT2232H core clock and EEPROM", 3)
    used = {str(index): None for index in range(1, 65)}
    for number in ("1", "5", "10", "11", "15", "25", "35", "47", "51"): used[number] = "GND"
    for number in ("12", "37", "64"): used[number] = "VCORE"
    used.update({"2": "FT_CLK12", "4": "VCC_3V3", "6": "FT_REF", "7": "USB_DM", "8": "USB_DP", "9": "VCC_3V3",
                 "13": "GND", "14": "FT_RESET_N", "16": "FT_A_TCK", "17": "FT_A_TDI", "18": "FT_A_TDO", "19": "FT_A_TMS",
                 "20": "VCC_3V3", "21": "FT_A_NTRST", "22": "FT_A_NSRST", "23": "FT_TARGET_EN", "31": "VCC_3V3",
                 "38": "FT_B_TXD", "39": "FT_B_RXD", "42": "VCC_3V3", "49": "VCORE", "50": "VCC_3V3", "56": "VCC_3V3",
                 "61": "EEDATA", "62": "EECLK", "63": "EECS"})
    add_symbol(p2, symbols["FTDI"], "U1", "FT2232HL", 120, 130, used)
    add_symbol(p2, symbols["EEPROM"], "U2", "93LC56BT-I/SN DNI", 220, 70, {"1": "EECS", "2": "EECLK", "3": "EEDATA", "4": "EEDATA", "5": "GND", "6": None, "7": None, "8": "VCC_3V3"}, dnp=True)
    add_symbol(p2, symbols["OSC"], "Y1", "12MHz", 220, 130, {"1": "VCC_3V3", "2": "GND", "3": "FT_CLK12", "4": "VCC_3V3"})
    add_symbol(p2, symbols["R"], "RREF", "12k 1%", 220, 180, {"1": "FT_REF", "2": "GND"})
    add_symbol(p2, symbols["R"], "RRESET", "10k", 290, 70, {"1": "FT_RESET_N", "2": "VCC_3V3"})
    add_symbol(p2, symbols["R"], "REECS", "10k", 290, 105, {"1": "EECS", "2": "GND"})
    add_symbol(p2, symbols["C0603"], "CCORE", "3.3u", 290, 145, {"1": "VCORE", "2": "GND"})
    for index, x in enumerate((190, 225, 260, 295, 330, 365), start=1):
        add_symbol(p2, symbols["C"], f"CDEC{index}", "100n", x, 225, {"1": "VCC_3V3", "2": "GND"})
    add_symbol(p2, symbols["GND"], "#PWR02", "GND", 365, 180, {"1": "GND"}, on_board=False)

    p3 = page("VREF detection and level shifting", 4)
    add_symbol(p3, symbols["COMP"], "U3", "TLV7041DBVR", 65, 85, {"1": "VREF_VALID", "2": "GND", "3": "VREF", "4": "VREF_THRESHOLD", "5": "VCC_3V3"})
    add_symbol(p3, symbols["R"], "RREF_TOP", "110k 1%", 65, 135, {"1": "VCC_3V3", "2": "VREF_THRESHOLD"})
    add_symbol(p3, symbols["R"], "RREF_BOT", "100k 1%", 65, 175, {"1": "VREF_THRESHOLD", "2": "GND"})
    add_symbol(p3, symbols["R"], "RVALID", "10k", 115, 135, {"1": "VREF_VALID", "2": "VCC_3V3"})
    add_symbol(p3, symbols["R"], "RTARGET_EN", "100k", 115, 175, {"1": "FT_TARGET_EN", "2": "GND"})
    add_symbol(p3, symbols["NAND"], "U7", "SN74LVC1G00DBVR", 170, 85, {"1": "VREF_VALID", "2": "FT_TARGET_EN", "3": "GND", "4": "SHIFT_OE_N", "5": "VCC_3V3"})
    add_symbol(p3, symbols["R"], "ROE", "100k", 170, 145, {"1": "SHIFT_OE_N", "2": "VCC_3V3"})
    add_symbol(p3, symbols["AXC8"], "U4", "SN74AXC8T245PWR", 260, 100, {
        "1": "VCC_3V3", "2": "VCC_3V3", "3": "FT_A_TCK", "4": "FT_A_TDI", "5": "FT_A_TMS", "6": "FT_A_NTRST",
        "7": "FT_A_NSRST", "8": "FT_B_TXD", "9": "U4_A7_UNUSED", "10": "U4_A8_UNUSED", "11": "VCC_3V3", "12": "GND", "13": "GND",
        "14": None, "15": None, "16": "UART_RXD_RAW", "17": "NSRST_RAW", "18": "NTRST_RAW", "19": "TMS_RAW", "20": "TDI_RAW",
        "21": "TCK_RAW", "22": "SHIFT_OE_N", "23": "VREF", "24": "VREF"})
    add_symbol(p3, symbols["AXC2"], "U5", "SN74AXC2T245RSWR", 350, 100, {"1": "GND", "2": "SHIFT_OE_N", "3": "GND", "4": "UART_TXD", "5": "TDO", "6": "VREF", "7": "VCC_3V3", "8": "FT_A_TDO", "9": "FT_B_RXD", "10": "GND"})
    add_symbol(p3, symbols["R"], "RU4_A7", "10k", 260, 165, {"1": "U4_A7_UNUSED", "2": "GND"})
    add_symbol(p3, symbols["R"], "RU4_A8", "10k", 330, 165, {"1": "U4_A8_UNUSED", "2": "GND"})
    for index, (rail, x) in enumerate((("VCC_3V3", 240), ("VREF", 275), ("VCC_3V3", 330), ("VREF", 365)), start=7):
        add_symbol(p3, symbols["C"], f"CDEC{index}", "100n", x, 210, {"1": rail, "2": "GND"})
    add_symbol(p3, symbols["NMOS"], "Q1", "2N7002", 115, 235, {"1": "VREF_VALID", "2": "GND", "3": "LED_VREF_K"})
    add_symbol(p3, symbols["R"], "RLED2", "2.2k", 175, 235, {"1": "VCC_3V3", "2": "LED_VREF_A"})
    add_symbol(p3, symbols["LED"], "D2", "AMBER", 235, 235, {"1": "LED_VREF_K", "2": "LED_VREF_A"})
    add_symbol(p3, symbols["PWR_FLAG"], "#FLG03", "PWR_FLAG", 350, 210, {"1": "VREF"}, on_board=False)
    add_symbol(p3, symbols["GND"], "#PWR03", "GND", 385, 210, {"1": "GND"}, on_board=False)

    p4 = page("Target connector ESD and test access", 5)
    series = (("RTCK", "TCK_RAW", "TCK"), ("RTMS", "TMS_RAW", "TMS"), ("RTDI", "TDI_RAW", "TDI"),
              ("RTRST", "NTRST_RAW", "nTRST"), ("RSRST", "NSRST_RAW", "nSRST"), ("RURX", "UART_RXD_RAW", "UART_RXD"))
    for index, (ref, source, target) in enumerate(series):
        add_symbol(p4, symbols["R"], ref, "33R", 75 + (index % 3) * 70, 55 + (index // 3) * 45, {"1": source, "2": target})
    add_symbol(p4, symbols["ESD8"], "ESD2", "TPD8E003DQDR", 285, 95, {"1": "TCK", "2": "TMS", "3": "TDI", "4": "TDO", "5": "nTRST", "6": "nSRST", "7": "UART_TXD", "8": "UART_RXD", "9": "GND"})
    add_symbol(p4, symbols["TARGET"], "J2", "WASP1 TARGET", 350, 95, {"1": "VREF", "2": "GND", "3": "TCK", "4": "GND", "5": "TMS", "6": "GND", "7": "TDI", "8": "TDO", "9": "nTRST", "10": "nSRST", "11": "UART_TXD", "12": "UART_RXD", "13": "GND", "14": None})
    for index, net in enumerate(("VCC_3V3", "VCORE", "VREF", "VREF_VALID", "FT_TARGET_EN", "SHIFT_OE_N", "TCK", "TDO"), start=1):
        add_symbol(p4, symbols["TP"], f"TP{index}", net, 55 + ((index - 1) % 4) * 80, 190 + ((index - 1) // 4) * 45, {"1": net})
    add_symbol(p4, symbols["GND"], "#PWR04", "GND", 365, 210, {"1": "GND"}, on_board=False)
    return [p1, p2, p3, p4]


def build_root(pages: list[Schematic], output: Path) -> Schematic:
    """Create the root hierarchy and aggregate all symbol instance paths."""
    root = page("wasp1 FT2232H Debugger Rev A", 1)
    root.sheetInstances = [HierarchicalSheetInstance(instancePath="/", page="1")]
    placements = ((55, 45), (55, 100), (55, 155), (55, 210))
    filenames = ("01_usb_power.kicad_sch", "02_ft2232h_core.kicad_sch", "03_vref_level_shift.kicad_sch", "04_target_io.kicad_sch")
    for index, (child, filename, (x, y)) in enumerate(zip(pages, filenames, placements), start=2):
        sheet_uuid = uid(f"root:sheet:{index}:{filename}")
        sheet = HierarchicalSheet(position=Position(x, y), width=300, height=40, stroke=Stroke(width=0), uuid=sheet_uuid)
        sheet.sheetName = symbol_property("Sheet name", child.titleBlock.title, x + 2.54, y + 2.54)
        sheet.fileName = symbol_property("Sheet file", filename, x + 2.54, y + 7.62)
        root.sheets.append(sheet)
        root.sheetInstances.append(HierarchicalSheetInstance(instancePath=f"/{sheet_uuid}", page=str(index)))
        for instance_uuid, ref, value, footprint in child._placed:
            root.symbolInstances.append(SymbolInstance(path=f"/{sheet_uuid}/{instance_uuid}", reference=ref, unit=1, value=value, footprint=footprint))
    return root


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="KiCad project output directory")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    symbols = build_symbols()
    pages = build_pages(symbols)
    filenames = ("01_usb_power.kicad_sch", "02_ft2232h_core.kicad_sch", "03_vref_level_shift.kicad_sch", "04_target_io.kicad_sch")
    for sch, filename in zip(pages, filenames):
        sch.to_file(str(args.output / filename))
    root = build_root(pages, args.output)
    root.to_file(str(args.output / f"{PROJECT}.kicad_sch"))
    SymbolLib(version="20231120", generator="wasp1_generator", symbols=list(symbols.values())).to_file(
        str(args.output / f"{PROJECT}.kicad_sym"))
    (args.output / f"{PROJECT}.kicad_pro").write_text(json.dumps({}, indent=2) + "\n", encoding="utf-8")
    (args.output / "sym-lib-table").write_text(
        f'(sym_lib_table\n  (lib (name "wasp1")(type "KiCad")(uri "${{KIPRJMOD}}/{PROJECT}.kicad_sym")(options "")(descr "wasp1 FTDI debugger Rev A symbols"))\n)\n',
        encoding="utf-8",
    )
    footprint_libraries = (
        "Capacitor_SMD", "Connector_IDC", "Connector_USB", "Fuse", "LED_SMD", "Oscillator",
        "Package_DFN_QFN", "Package_QFP", "Package_SO", "Package_SON", "Package_TO_SOT_SMD",
        "Resistor_SMD", "TestPoint",
    )
    fp_rows = "\n".join(
        f'  (lib (name "{name}")(type "KiCad")(uri "${{KICAD10_FOOTPRINT_DIR}}/{name}.pretty")(options "")(descr ""))'
        for name in footprint_libraries
    )
    (args.output / "fp-lib-table").write_text(f"(fp_lib_table\n{fp_rows}\n)\n", encoding="utf-8")


if __name__ == "__main__":
    main()
