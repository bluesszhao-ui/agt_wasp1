#!/usr/bin/env python3
"""Render wasp1 state-machine/state-transition PNG diagrams.

The script intentionally uses only the Python standard library so the diagrams
can be regenerated on a clean machine without Graphviz, PIL, or ImageMagick.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import math
import struct
import zlib


Color = tuple[int, int, int, int]

WHITE: Color = (255, 255, 255, 255)
BLACK: Color = (25, 28, 31, 255)
BLUE: Color = (220, 235, 255, 255)
GREEN: Color = (224, 246, 230, 255)
YELLOW: Color = (255, 244, 204, 255)
PINK: Color = (255, 229, 229, 255)
GRAY: Color = (242, 244, 247, 255)
DARK_GRAY: Color = (90, 96, 105, 255)
GRID_MINOR: Color = (235, 238, 242, 255)
GRID_MAJOR: Color = (214, 219, 226, 255)
ACTION_GRAY: Color = (218, 222, 228, 255)
COND_GREEN: Color = (42, 140, 64, 255)

# Timing-class color policy.  The main fill color of every diagram node is
# reserved for the circuit timing class, not for semantic state meaning.
SEQ_FILL: Color = GREEN
COMB_FILL: Color = YELLOW
IF_FILL: Color = BLUE
NEUTRAL_FILL: Color = GRAY


FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    "_": ["00000", "00000", "00000", "00000", "00000", "00000", "11111"],
    "/": ["00001", "00001", "00010", "00100", "01000", "10000", "10000"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    "=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ",": ["00000", "00000", "00000", "00000", "00110", "00100", "01000"],
    ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    "(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
    ")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
    "[": ["11100", "10000", "10000", "10000", "10000", "10000", "11100"],
    "]": ["00111", "00001", "00001", "00001", "00001", "00001", "00111"],
    "<": ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
    ">": ["01000", "00100", "00010", "00001", "00010", "00100", "01000"],
    "&": ["01100", "10010", "10100", "01000", "10101", "10010", "01101"],
    "|": ["00100", "00100", "00100", "00100", "00100", "00100", "00100"],
    "*": ["00000", "10101", "01110", "11111", "01110", "10101", "00000"],
}


@dataclass(frozen=True)
class Node:
    key: str
    x: int
    y: int
    w: int
    h: int
    lines: tuple[str, ...]
    fill: Color = GRAY


@dataclass(frozen=True)
class Edge:
    src: str
    dst: str
    label: str = ""
    bend: tuple[int, int] | None = None


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.pix = bytearray(WHITE * width * height)

    def set_px(self, x: int, y: int, c: Color) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            i = (y * self.width + x) * 4
            self.pix[i : i + 4] = bytes(c)

    def rect(self, x: int, y: int, w: int, h: int, fill: Color, outline: Color = BLACK) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set_px(xx, yy, fill)
        self.line(x, y, x + w, y, outline, 2)
        self.line(x, y + h, x + w, y + h, outline, 2)
        self.line(x, y, x, y + h, outline, 2)
        self.line(x + w, y, x + w, y + h, outline, 2)

    def grid(self, minor: int = 10, major: int = 50) -> None:
        for x in range(0, self.width, minor):
            self.line(x, 0, x, self.height - 1, GRID_MINOR, 1)
        for y in range(0, self.height, minor):
            self.line(0, y, self.width - 1, y, GRID_MINOR, 1)
        for x in range(0, self.width, major):
            self.line(x, 0, x, self.height - 1, GRID_MAJOR, 1)
        for y in range(0, self.height, major):
            self.line(0, y, self.width - 1, y, GRID_MAJOR, 1)

    def ellipse(self, x: int, y: int, w: int, h: int, fill: Color, outline: Color = BLACK, thick: int = 2) -> None:
        cx = x + w / 2
        cy = y + h / 2
        rx = w / 2
        ry = h / 2
        for yy in range(y, y + h + 1):
            for xx in range(x, x + w + 1):
                n = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
                if n <= 1.0:
                    self.set_px(xx, yy, fill)
        for yy in range(y - thick, y + h + thick + 1):
            for xx in range(x - thick, x + w + thick + 1):
                n = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
                if 0.92 <= n <= 1.08:
                    self.set_px(xx, yy, outline)

    def box_text(self, x: int, y: int, lines: list[str], title: str = "", fill: Color = (248, 249, 251, 255)) -> None:
        max_w = max([self.text_width(title, 1)] + [self.text_width(line, 1) for line in lines]) + 22
        h = 22 + 16 * len(lines) + (18 if title else 0)
        self.rect(x, y, max_w, h, fill, DARK_GRAY)
        ty = y + 10
        if title:
            self.text(x + 10, ty, title, scale=1, color=BLACK)
            ty += 18
        for line in lines:
            color = COND_GREEN if line.strip().startswith("&&") or line.strip().startswith("OR") else DARK_GRAY
            if line.strip().startswith("ACTION"):
                color = BLACK
            self.text(x + 10, ty, line, scale=1, color=color)
            ty += 16

    def class_fill(self, lines: tuple[str, ...], fallback: Color = NEUTRAL_FILL) -> Color:
        """Return the uniform fill color for a node's timing class label."""
        if not lines:
            return fallback
        label = lines[0].strip().upper()
        if label == "SEQ":
            return SEQ_FILL
        if label == "COMB":
            return COMB_FILL
        if label == "IF":
            return IF_FILL
        return fallback

    def state(self, x: int, y: int, w: int, h: int, lines: tuple[str, ...], fill: Color = WHITE) -> None:
        self.ellipse(x, y, w, h, self.class_fill(lines, fill), BLACK, 2)
        total_h = len(lines) * 22
        ty = y + (h - total_h) // 2
        for line in lines:
            tx = x + (w - self.text_width(line, 2)) // 2
            self.text(tx, ty, line, scale=2, color=BLACK)
            ty += 22

    def action_label(self, x: int, y: int, lines: list[str]) -> None:
        max_w = max(self.text_width(line, 1) for line in lines) + 18
        h = 14 * len(lines) + 12
        self.rect(x, y, max_w, h, ACTION_GRAY, ACTION_GRAY)
        ty = y + 7
        for line in lines:
            self.text(x + 8, ty, line, scale=1, color=DARK_GRAY)
            ty += 14

    def line(self, x0: int, y0: int, x1: int, y1: int, c: Color = BLACK, thick: int = 1) -> None:
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        x, y = x0, y0
        while True:
            r = thick // 2
            for yy in range(y - r, y + r + 1):
                for xx in range(x - r, x + r + 1):
                    self.set_px(xx, yy, c)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def arrow(self, x0: int, y0: int, x1: int, y1: int, label: str = "") -> None:
        self.line(x0, y0, x1, y1, BLACK, 2)
        angle = math.atan2(y1 - y0, x1 - x0)
        for delta in (2.55, -2.55):
            ax = int(x1 - 13 * math.cos(angle + delta))
            ay = int(y1 - 13 * math.sin(angle + delta))
            self.line(x1, y1, ax, ay, BLACK, 2)
        if label:
            lx = (x0 + x1) // 2
            ly = (y0 + y1) // 2 - 12
            self.text(lx - self.text_width(label, 1) // 2, ly, label, scale=1, color=DARK_GRAY)

    def path_arrow(self, points: list[tuple[int, int]], label: str = "") -> None:
        if len(points) < 2:
            return
        for (x0, y0), (x1, y1) in zip(points, points[1:-1]):
            self.line(x0, y0, x1, y1, BLACK, 2)
        x0, y0 = points[-2]
        x1, y1 = points[-1]
        self.arrow(x0, y0, x1, y1, label)

    def text_width(self, s: str, scale: int = 2) -> int:
        return sum((6 if ch.upper() in FONT else 6) * scale for ch in s)

    def text(self, x: int, y: int, s: str, scale: int = 2, color: Color = BLACK) -> None:
        cx = x
        for ch in s.upper():
            glyph = FONT.get(ch, FONT["?"])
            for gy, row in enumerate(glyph):
                for gx, bit in enumerate(row):
                    if bit == "1":
                        for yy in range(scale):
                            for xx in range(scale):
                                self.set_px(cx + gx * scale + xx, y + gy * scale + yy, color)
            cx += 6 * scale

    def write_png(self, path: Path) -> None:
        raw = bytearray()
        stride = self.width * 4
        for y in range(self.height):
            raw.append(0)
            raw.extend(self.pix[y * stride : (y + 1) * stride])
        compressed = zlib.compress(bytes(raw), 9)

        def chunk(kind: bytes, data: bytes) -> bytes:
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", compressed)
        png += chunk(b"IEND", b"")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(png)


def center(node: Node) -> tuple[int, int]:
    return (node.x + node.w // 2, node.y + node.h // 2)


def anchor(src: Node, dst: Node) -> tuple[int, int, int, int]:
    sx, sy = center(src)
    dx, dy = center(dst)
    if abs(dx - sx) > abs(dy - sy):
        x0 = src.x + (src.w if dx > sx else 0)
        y0 = sy
        x1 = dst.x if dx > sx else dst.x + dst.w
        y1 = dy
    else:
        x0 = sx
        y0 = src.y + (src.h if dy > sy else 0)
        x1 = dx
        y1 = dst.y if dy > sy else dst.y + dst.h
    return x0, y0, x1, y1


def render(path: str, title: str, nodes: list[Node], edges: list[Edge], notes: list[str], width: int = 1280, height: int = 760) -> None:
    canvas = Canvas(width, height)
    canvas.text(36, 28, title, scale=3, color=BLACK)
    node_map = {node.key: node for node in nodes}
    for edge in edges:
        src = node_map[edge.src]
        dst = node_map[edge.dst]
        if edge.bend:
            x0, y0, _, _ = anchor(src, Node("bend", edge.bend[0] - 1, edge.bend[1] - 1, 2, 2, ("",)))
            _, _, x1, y1 = anchor(Node("bend", edge.bend[0] - 1, edge.bend[1] - 1, 2, 2, ("",)), dst)
            canvas.line(x0, y0, edge.bend[0], edge.bend[1], BLACK, 2)
            canvas.arrow(edge.bend[0], edge.bend[1], x1, y1, edge.label)
        else:
            canvas.arrow(*anchor(src, dst), edge.label)
    for node in nodes:
        canvas.rect(node.x, node.y, node.w, node.h, canvas.class_fill(node.lines, node.fill))
        total_h = len(node.lines) * 20
        ty = node.y + (node.h - total_h) // 2
        for line in node.lines:
            tx = node.x + (node.w - canvas.text_width(line, 2)) // 2
            canvas.text(tx, ty, line, scale=2, color=BLACK)
            ty += 20
    y = height - 150
    canvas.text(36, y, "NOTES", scale=2, color=DARK_GRAY)
    y += 28
    for note in notes[:6]:
        canvas.text(52, y, "- " + note, scale=2, color=DARK_GRAY)
        y += 24
    canvas.write_png(Path(path))


def render_core_pipe_l3() -> None:
    canvas = Canvas(1900, 1100)
    canvas.grid()
    canvas.text(40, 34, "CORE_PIPE L3 INSTRUCTION STREAM / PIPELINE PRIORITY", scale=3, color=BLACK)
    canvas.box_text(
        40,
        90,
        [
            "GREEN TEXT : JUMP CONDITION",
            "GRAY BOX   : REGISTER ACTION",
            "SEQ        : CLK_I WITH RST_NI",
            "COMB       : STATE-FREE CONTROL",
            "PRIORITY   : REDIRECT > BUBBLE > ADVANCE",
            "PC OWNER   : FRONTEND",
        ],
        "LEGEND",
    )

    canvas.state(120, 340, 160, 95, ("SEQ", "RESET", "SLOTS"), BLUE)
    canvas.state(390, 315, 260, 120, ("IF", "FRONTEND", "INSTR STREAM"), BLUE)
    canvas.state(750, 315, 240, 120, ("COMB", "ACCEPT", "CTRL"), YELLOW)
    canvas.state(1090, 315, 220, 120, ("SEQ", "IF/ID"), GREEN)
    canvas.state(1450, 315, 220, 120, ("SEQ", "EX/WB"), GREEN)
    canvas.state(790, 660, 270, 125, ("COMB", "REDIRECT", "FLUSH"), PINK)
    canvas.state(1300, 660, 260, 125, ("COMB", "EXEC", "BUBBLE"), PINK)

    canvas.path_arrow([(280, 388), (390, 375)], "RST_N=1")
    canvas.path_arrow([(650, 375), (750, 375)], "INSTR_VALID")
    canvas.path_arrow([(990, 375), (1090, 375)], "INSTR_FIRE")
    canvas.path_arrow([(1310, 375), (1450, 375)], "ADVANCE")
    canvas.path_arrow([(880, 660), (1110, 435)], "FLUSH IF/ID")
    canvas.path_arrow([(980, 660), (1480, 435)], "FLUSH EX/WB")
    canvas.path_arrow([(900, 785), (520, 435)], "REDIRECT TO FRONTEND")
    canvas.path_arrow([(1415, 660), (1530, 435)], "CLEAR EX/WB")

    canvas.box_text(
        620,
        120,
        [
            "&& INSTR_VALID_I",
            "&& !FETCH_STALL_I",
            "&& !DECODE_STALL_I",
            "&& !REDIRECT_VALID_I",
            "ACTION INSTR_READY_O=1",
            "ACTION IF/ID <= STREAM BEAT",
        ],
        "INSTR_FIRE",
    )
    canvas.box_text(
        1020,
        120,
        [
            "&& !DECODE_STALL_I",
            "&& !EXECUTE_BUBBLE_I",
            "&& !REDIRECT_VALID_I",
            "ACTION EX/WB <= OLD IF/ID",
            "ACTION IF/ID <= NEXT OR NOP",
        ],
        "ADVANCE",
    )
    canvas.box_text(
        1010,
        770,
        [
            "&& REDIRECT_VALID_I",
            "ACTION REDIRECT_VALID_O=1",
            "ACTION REDIRECT_PC_O=REDIRECT_PC_I",
            "ACTION IF/ID <= INVALID NOP",
            "ACTION EX/WB <= INVALID NOP",
        ],
        "HIGHEST PRIORITY",
    )
    canvas.box_text(
        1320,
        835,
        [
            "&& EXECUTE_BUBBLE_I",
            "&& !REDIRECT_VALID_I",
            "ACTION EX/WB <= INVALID NOP",
            "NOTE IF/ID HOLDS IF DECODE_STALL_I",
        ],
        "LOAD USE BUBBLE",
    )
    canvas.action_label(390, 460, ["FRONTEND OWNS PC", "BOOT/PC+4/REDIRECT"])
    canvas.action_label(735, 460, ["INSTR_READY = ACCEPT", "STALLS MAKE READY=0", "NO PC REGISTER HERE"])
    canvas.action_label(1080, 460, ["ID_VALID/PC/INSTR/FAULT", "CAPTURED FROM STREAM", "HELD BY DECODE_STALL"])
    canvas.action_label(1440, 460, ["EX_VALID/PC/INSTR/FAULT", "CAPTURED FROM OLD IF/ID", "CLEARED BY BUBBLE"])

    canvas.text(40, 985, "NOTE: THIS PNG IS GENERATED BY DOCS/TOOLS/RENDER_STATE_PNGS.PY", scale=2, color=DARK_GRAY)
    canvas.write_png(Path("core/docs/images/core_pipe_state.png"))


def render_ahb_dma_l3() -> None:
    canvas = Canvas(2200, 1250)
    canvas.grid()
    canvas.text(40, 34, "AHB_DMA L3 MAIN CONTROL FSM", scale=3, color=BLACK)
    canvas.box_text(
        40,
        90,
        [
            "GREEN TEXT : JUMP CONDITION",
            "GRAY BOX   : REGISTER ACTION",
            "SEQ        : HCLK_I WITH HRESETN_I",
            "COMB       : STATE-FREE CONTROL",
            "MAIN PATH  : LEFT TO RIGHT",
            "ERROR PATH : DROPS TO LOWER RED AREA",
        ],
        "LEGEND",
    )

    canvas.state(100, 430, 150, 95, ("SEQ", "IDLE"), GREEN)
    canvas.state(390, 430, 210, 95, ("SEQ", "READ", "ADDR"), YELLOW)
    canvas.state(720, 430, 210, 95, ("SEQ", "READ", "DATA"), YELLOW)
    canvas.state(1060, 430, 220, 95, ("SEQ", "WRITE", "ADDR"), YELLOW)
    canvas.state(1410, 430, 220, 95, ("SEQ", "WRITE", "RESP"), YELLOW)
    canvas.state(1800, 360, 170, 95, ("SEQ", "DONE"), GREEN)
    canvas.state(1800, 710, 170, 95, ("SEQ", "ERROR"), PINK)
    canvas.state(1980, 535, 170, 95, ("COMB", "IRQ"), GRAY)

    canvas.path_arrow([(250, 477), (390, 477)], "START OK")
    canvas.path_arrow([(600, 477), (720, 477)], "HREADY")
    canvas.path_arrow([(930, 477), (1060, 477)], "READ OK")
    canvas.path_arrow([(1280, 477), (1410, 477)], "HREADY")
    canvas.path_arrow([(1630, 477), (1800, 405)], "LAST OK")
    canvas.path_arrow([(1520, 525), (1520, 625), (830, 625), (830, 525)], "MORE")
    canvas.path_arrow([(1800, 405), (2040, 535)], "DONE IRQ")
    canvas.path_arrow([(1800, 758), (2040, 630)], "ERR IRQ")

    canvas.path_arrow([(175, 525), (175, 710), (1800, 758)], "BAD START")
    canvas.path_arrow([(825, 525), (825, 710), (1800, 758)], "READ ERR")
    canvas.path_arrow([(1520, 525), (1520, 710), (1800, 758)], "WRITE ERR")
    canvas.path_arrow([(1885, 455), (1885, 1040), (175, 1040), (175, 525)], "CTRL CLEAR")
    canvas.path_arrow([(1885, 805), (1885, 1100), (175, 1100), (175, 525)], "CTRL CLEAR")

    canvas.box_text(
        270,
        300,
        [
            "&& STATE == IDLE",
            "&& CTRL.START",
            "&& LEN_Q != 0",
            "&& SRC_Q[1:0] == 0",
            "&& DST_Q[1:0] == 0",
            "ACTION BUSY=1",
            "ACTION DONE=0 ERROR=0",
            "ACTION REMAINING=LEN_Q",
            "ACTION CUR_SRC=SRC_Q",
            "ACTION CUR_DST=DST_Q",
        ],
        "START ACCEPT",
    )
    canvas.box_text(
        380,
        570,
        [
            "ACTION M_HTRANS=NONSEQ",
            "ACTION M_HWRITE=0",
            "ACTION M_HADDR=CUR_SRC",
            "ACTION M_HSIZE=WORD",
            "&& M_HREADY",
        ],
        "READ ADDRESS",
    )
    canvas.box_text(
        710,
        570,
        [
            "&& M_HREADY",
            "&& M_HRESP == OKAY",
            "ACTION READ_DATA_Q <= M_HRDATA",
            "OR M_HRESP == ERROR",
            "  -> ERROR",
        ],
        "READ RESPONSE",
    )
    canvas.box_text(
        1050,
        570,
        [
            "ACTION M_HTRANS=NONSEQ",
            "ACTION M_HWRITE=1",
            "ACTION M_HADDR=CUR_DST",
            "ACTION M_HWDATA=READ_DATA_Q",
            "ACTION M_HSIZE=WORD",
            "&& M_HREADY",
        ],
        "WRITE ADDRESS",
    )
    canvas.box_text(
        1350,
        570,
        [
            "&& M_HREADY",
            "&& M_HRESP == OKAY",
            "&& REMAINING > 1",
            "ACTION CUR_SRC += 4",
            "ACTION CUR_DST += 4",
            "ACTION REMAINING -= 1",
        ],
        "MORE WORDS",
    )
    canvas.box_text(
        1645,
        245,
        [
            "&& M_HREADY",
            "&& M_HRESP == OKAY",
            "&& REMAINING == 1",
            "ACTION BUSY=0",
            "ACTION DONE=1",
            "ACTION ERROR=0",
        ],
        "LAST WORD",
    )
    canvas.box_text(
        1490,
        805,
        [
            "OR BAD START",
            "OR READ HRESP ERROR",
            "OR WRITE HRESP ERROR",
            "ACTION BUSY=0",
            "ACTION DONE=0",
            "ACTION ERROR=1",
        ],
        "ERROR ENTRY",
    )
    canvas.box_text(
        1850,
        820,
        [
            "&& CTRL.CLEAR",
            "ACTION DONE=0",
            "ACTION ERROR=0",
            "ACTION IRQ DEASSERTS",
        ],
        "CLEAR STATUS",
    )
    canvas.action_label(1970, 660, ["DMA_IRQ_O = IRQ_ENABLE", "&& (DONE || ERROR)"])
    canvas.action_label(70, 590, ["BAD START IF:", "LEN=0 OR SRC/DST UNALIGNED"])
    canvas.text(40, 1150, "NOTE: SLAVE REGISTER AHB RESPONSE PATH IS SPLIT INTO A SEPARATE PNG.", scale=2, color=DARK_GRAY)
    canvas.text(40, 1180, "NOTE: THIS PNG IS GENERATED BY DOCS/TOOLS/RENDER_STATE_PNGS.PY", scale=2, color=DARK_GRAY)
    canvas.write_png(Path("dma/docs/images/ahb_dma_fsm.png"))

    reg = Canvas(1700, 900)
    reg.grid()
    reg.text(40, 34, "AHB_DMA L3 SLAVE REGISTER PATH", scale=3, color=BLACK)
    reg.box_text(
        40,
        90,
        [
            "ONE CYCLE AHB RESPONSE MODEL",
            "SEQ : HCLK_I WITH HRESETN_I",
            "COMB: STATE-FREE MUX/DECODE",
            "CAPTURE ADDRESS PHASE AT CYCLE N",
            "RETURN RESPONSE AT CYCLE N+1",
        ],
        "LEGEND",
    )
    reg.state(110, 360, 180, 90, ("SEQ", "IDLE"), GRAY)
    reg.state(390, 360, 240, 90, ("SEQ", "CAPTURE"), BLUE)
    reg.state(760, 190, 220, 90, ("COMB", "READ MUX"), GREEN)
    reg.state(760, 360, 220, 90, ("COMB", "ERROR"), PINK)
    reg.state(760, 530, 220, 90, ("SEQ", "WRITE REGS"), GREEN)
    reg.state(1160, 360, 220, 90, ("SEQ", "RESPOND"), YELLOW)

    reg.path_arrow([(290, 405), (390, 405)], "S_HSEL && HTRANS[1]")
    reg.path_arrow([(630, 405), (760, 235)], "READ OK")
    reg.path_arrow([(630, 405), (760, 405)], "BAD XFER")
    reg.path_arrow([(630, 405), (760, 575)], "WRITE OK")
    reg.path_arrow([(980, 235), (1160, 385)], "HRDATA")
    reg.path_arrow([(980, 405), (1160, 405)], "ERROR")
    reg.path_arrow([(980, 575), (1160, 425)], "OKAY")
    reg.path_arrow([(1270, 450), (1270, 735), (200, 735), (200, 450)], "NEXT CYCLE")
    reg.box_text(
        350,
        500,
        [
            "CAPTURED:",
            "S_HADDR",
            "S_HWRITE",
            "S_HSIZE",
            "REG OFFSET",
            "ERROR CLASS",
        ],
        "CYCLE N",
    )
    reg.box_text(
        720,
        70,
        [
            "READ DMA_SRC/DST/LEN",
            "READ CTRL/STATUS",
            "READ RETURNS REGISTER IMAGE",
            "ACTION S_HRESP=OKAY",
        ],
        "READ RESPONSE",
    )
    reg.box_text(
        720,
        650,
        [
            "WRITE SRC/DST/LEN IF IDLE",
            "CTRL.START REQUESTS FSM START",
            "CTRL.CLEAR CLEARS DONE/ERROR",
            "ACTION S_HRESP=OKAY",
        ],
        "WRITE RESPONSE",
    )
    reg.box_text(
        1040,
        500,
        [
            "OR OUT OF RANGE",
            "OR MISALIGNED",
            "OR HSIZE != WORD",
            "OR UNKNOWN REG",
            "ACTION S_HRESP=ERROR",
        ],
        "ERROR RESPONSE",
    )
    reg.text(40, 830, "NOTE: THIS PNG IS GENERATED BY DOCS/TOOLS/RENDER_STATE_PNGS.PY", scale=2, color=DARK_GRAY)
    reg.write_png(Path("dma/docs/images/ahb_dma_reg_path.png"))


def render_icache_ctrl_l3() -> None:
    canvas = Canvas(2100, 1180)
    canvas.grid()
    canvas.text(40, 34, "ICACHE_CTRL L3 HIT MISS CONTROL FSM", scale=3, color=BLACK)
    canvas.box_text(
        40,
        90,
        [
            "GREEN TEXT : JUMP CONDITION",
            "GRAY BOX   : REGISTER OR OUTPUT ACTION",
            "SEQ        : CLK_I WITH RST_NI",
            "COMB       : STATE FREE CLASSIFY OR MUX",
            "IF         : EXTERNAL VALID READY PORT",
            "PRIORITY   : RESET > FLUSH > NORMAL",
        ],
        "LEGEND",
    )

    canvas.state(120, 455, 170, 95, ("SEQ", "IDLE"), GREEN)
    canvas.state(500, 260, 220, 100, ("COMB", "REQ", "CLASSIFY"), YELLOW)
    canvas.state(500, 620, 220, 100, ("COMB", "LOOKUP", "HIT MISS"), YELLOW)
    canvas.state(860, 455, 220, 100, ("SEQ", "MISS", "REQ"), YELLOW)
    canvas.state(1220, 455, 230, 100, ("SEQ", "MISS", "WAIT"), YELLOW)
    canvas.state(1620, 455, 190, 100, ("SEQ", "RESP"), GREEN)
    canvas.state(1220, 755, 250, 100, ("COMB", "REFILL", "UPDATE"), GREEN)
    canvas.state(1620, 755, 230, 100, ("COMB", "RSP", "MUX"), GREEN)
    canvas.state(860, 120, 230, 90, ("IF", "FRONT", "REQ RSP"), BLUE)
    canvas.state(1220, 120, 230, 90, ("IF", "TAG DATA", "LOOKUP"), BLUE)
    canvas.state(1220, 980, 230, 90, ("IF", "REFILL", "PORT"), BLUE)

    canvas.path_arrow([(290, 502), (500, 310)], "REQ FIRE")
    canvas.path_arrow([(720, 310), (1220, 165)], "LOOKUP ADDR")
    canvas.path_arrow([(720, 670), (500, 360)], "HIT DATA")
    canvas.path_arrow([(720, 670), (860, 505)], "MISS")
    canvas.path_arrow([(720, 310), (1620, 505)], "INVALID")
    canvas.path_arrow([(1080, 505), (1220, 505)], "START FIRE")
    canvas.path_arrow([(1450, 505), (1620, 505)], "LINE FIRE")
    canvas.path_arrow([(1810, 505), (1950, 505), (1950, 260), (205, 260), (205, 455)], "RSP FIRE")
    canvas.path_arrow([(1320, 555), (1320, 755)], "LINE FIRE")
    canvas.path_arrow([(1470, 805), (1620, 805)], "SELECT WORD")
    canvas.path_arrow([(1735, 755), (1735, 555)], "RSP DATA ERR")
    canvas.path_arrow([(1335, 855), (1335, 980)], "TAG DATA WRITE")
    canvas.path_arrow([(970, 555), (970, 1010), (1220, 1010)], "START")
    canvas.path_arrow([(1335, 980), (1335, 855)], "LINE")
    canvas.path_arrow([(1030, 120), (620, 260)], "FRONT IF")
    canvas.path_arrow([(1030, 120), (1715, 455)], "RSP READY")

    canvas.box_text(
        325,
        370,
        [
            "&& STATE == IDLE",
            "&& FRONT_REQ_VALID",
            "&& FRONT_REQ_READY",
            "ACTION MISS_ADDR_Q <= REQ_ADDR",
        ],
        "REQUEST ACCEPT",
    )
    canvas.box_text(
        300,
        90,
        [
            "OR REQ_WRITE",
            "OR REQ_SIZE != 2",
            "OR !REQ_INSTR",
            "OR REQ_ADDR[1:0] != 0",
            "ACTION RSP_DATA_Q = 0",
            "ACTION RSP_ERR_Q = 1",
        ],
        "INVALID REQUEST",
    )
    canvas.box_text(
        710,
        610,
        [
            "&& !INVALID_REQ",
            "&& TAG_HIT_I",
            "ACTION RSP_DATA_Q = DATA_WORD_I",
            "ACTION RSP_ERR_Q = 0",
            "NEXT RESP",
        ],
        "HIT RESPONSE",
    )
    canvas.box_text(
        780,
        330,
        [
            "&& !INVALID_REQ",
            "&& !TAG_HIT_I",
            "ACTION REFILL_START_ADDR = MISS_ADDR_Q",
            "HOLD VALID UNTIL START_READY",
        ],
        "MISS START",
    )
    canvas.box_text(
        1160,
        600,
        [
            "&& REFILL_LINE_VALID",
            "&& REFILL_LINE_READY",
            "ACTION TAG_REFILL_VALID = 1",
            "ACTION DATA_REFILL_VALID = 1",
            "ACTION RSP_ERR_Q = LINE_ERROR",
        ],
        "LINE ACCEPT",
    )
    canvas.box_text(
        1480,
        900,
        [
            "WORD_INDEX = MISS_ADDR_Q[3:2]",
            "ACTION RSP_DATA_Q = LINE_WORD",
            "ACTION FRONT_RSP_VALID = RESP",
            "HOLD UNTIL FRONT_RSP_READY",
        ],
        "RESPONSE MUX",
    )
    canvas.box_text(
        650,
        900,
        [
            "&& FLUSH_I",
            "ACTION STATE_Q = IDLE",
            "ACTION RSP_ERR_Q = 0",
            "ACTION SUPPRESS RSP AND UPDATE",
            "ACTION REFILL_FLUSH_O = 1",
        ],
        "FLUSH PRIORITY",
    )

    canvas.action_label(80, 585, ["REQ_READY = IDLE && !FLUSH", "LOOKUP_VALID = REQ_VALID && IDLE"])
    canvas.action_label(835, 575, ["START_VALID = MISS_REQ", "START_ADDR = MISS_ADDR_Q"])
    canvas.action_label(1210, 875, ["TAG ERROR = LINE_ERROR", "DATA LINE = REFILL_LINE_DATA"])
    canvas.action_label(1600, 585, ["RSP_VALID = RESP", "RSP_RDATA/RSP_ERR HELD"])

    canvas.text(40, 1110, "NOTE: THIS PNG IS GENERATED BY DOCS/TOOLS/RENDER_STATE_PNGS.PY", scale=2, color=DARK_GRAY)
    canvas.write_png(Path("icache/docs/images/icache_ctrl_fsm.png"))


def render_dcache_ctrl_l3() -> None:
    canvas = Canvas(2300, 1300)
    canvas.grid()
    canvas.text(40, 34, "DCACHE_CTRL L3 LOAD STORE CONTROL FSM", scale=3, color=BLACK)
    canvas.box_text(
        40,
        90,
        [
            "GREEN TEXT : JUMP CONDITION",
            "GRAY BOX   : REGISTER OR UPDATE ACTION",
            "SEQ        : CLK_I WITH RST_NI",
            "COMB       : STATE FREE CLASSIFY OR MUX",
            "IF         : VALID READY PORT",
            "PRIORITY   : RESET > FLUSH > NORMAL",
        ],
        "LEGEND",
    )

    canvas.state(120, 560, 170, 95, ("SEQ", "IDLE"), GREEN)
    canvas.state(430, 440, 250, 105, ("COMB", "REQ", "CLASSIFY"), YELLOW)
    canvas.state(420, 170, 240, 95, ("IF", "CORE", "REQ/RSP"), BLUE)
    canvas.state(730, 440, 240, 95, ("IF", "TAG DATA", "LOOKUP"), BLUE)
    canvas.state(1040, 250, 240, 95, ("SEQ", "LOAD", "REFILL REQ"), YELLOW)
    canvas.state(1380, 250, 250, 95, ("SEQ", "LOAD", "REFILL WAIT"), YELLOW)
    canvas.state(1380, 55, 250, 95, ("IF", "REFILL", "START/LINE"), BLUE)
    canvas.state(1690, 250, 260, 95, ("COMB", "REFILL", "UPDATE WORD"), GREEN)
    canvas.state(1040, 780, 240, 95, ("SEQ", "STORE", "REQ"), YELLOW)
    canvas.state(1380, 780, 250, 95, ("SEQ", "STORE", "WAIT"), YELLOW)
    canvas.state(1380, 975, 250, 95, ("IF", "STORE", "START/DONE"), BLUE)
    canvas.state(1690, 780, 260, 95, ("COMB", "STORE HIT", "UPDATE"), GREEN)
    canvas.state(2020, 515, 190, 95, ("SEQ", "RESP"), GREEN)
    canvas.state(2000, 700, 240, 95, ("COMB", "RSP", "DATA ERR"), GREEN)
    canvas.state(1030, 520, 260, 105, ("COMB", "FLUSH", "ABORT"), PINK)

    canvas.path_arrow([(290, 608), (430, 492)], "REQ_FIRE")
    canvas.path_arrow([(540, 265), (540, 440)], "REQ FIELDS")
    canvas.path_arrow([(680, 492), (730, 492)], "LOOKUP")
    canvas.path_arrow([(730, 535), (610, 610), (430, 545)], "TAG_HIT DATA")
    canvas.path_arrow([(680, 465), (1040, 298)], "LOAD MISS")
    canvas.path_arrow([(680, 520), (1040, 828)], "STORE")
    canvas.path_arrow([(680, 492), (2020, 562)], "INVALID OR LOAD HIT")
    canvas.path_arrow([(1280, 298), (1380, 298)], "START_READY")
    canvas.path_arrow([(1505, 250), (1505, 150)], "REFILL START")
    canvas.path_arrow([(1505, 150), (1505, 250)], "LINE_VALID")
    canvas.path_arrow([(1630, 298), (1690, 298)], "LINE_FIRE")
    canvas.path_arrow([(1950, 298), (2020, 562)], "RSP_WORD ERR")
    canvas.path_arrow([(1280, 828), (1380, 828)], "START_READY")
    canvas.path_arrow([(1505, 875), (1505, 975)], "STORE START")
    canvas.path_arrow([(1505, 975), (1505, 875)], "DONE_VALID")
    canvas.path_arrow([(1630, 828), (1690, 828)], "DONE_FIRE")
    canvas.path_arrow([(1950, 828), (2020, 562)], "RSP_ERR")
    canvas.path_arrow([(2115, 610), (2115, 700)], "RSP_VALID")
    canvas.path_arrow([(2115, 795), (2115, 1120), (205, 1120), (205, 655)], "RSP_READY")

    canvas.path_arrow([(1160, 345), (1160, 520)], "FLUSH")
    canvas.path_arrow([(1505, 345), (1210, 520)], "FLUSH")
    canvas.path_arrow([(1160, 780), (1160, 625)], "FLUSH")
    canvas.path_arrow([(1505, 780), (1210, 625)], "FLUSH")
    canvas.path_arrow([(2020, 562), (1290, 572)], "FLUSH")
    canvas.path_arrow([(1030, 572), (290, 608)], "NEXT")

    canvas.box_text(
        330,
        300,
        [
            "&& STATE == IDLE",
            "&& CORE_REQ_VALID",
            "&& CORE_REQ_READY",
            "ACTION CAPTURE ADDR/SIZE",
            "ACTION CAPTURE WDATA/WSTRB",
        ],
        "REQUEST ACCEPT",
    )
    canvas.box_text(
        720,
        210,
        [
            "OR REQ_INSTR",
            "OR SIZE == 3",
            "OR HALF && ADDR[0]",
            "OR WORD && ADDR[1:0]!=0",
            "ACTION RSP_ERR_Q = 1",
        ],
        "INVALID REQUEST",
    )
    canvas.box_text(
        700,
        575,
        [
            "&& !REQ_WRITE",
            "&& TAG_HIT_I",
            "ACTION RSP_DATA_Q = DATA_WORD_I",
            "ACTION RSP_ERR_Q = 0",
        ],
        "LOAD HIT",
    )
    canvas.box_text(
        940,
        115,
        [
            "&& !REQ_WRITE",
            "&& !TAG_HIT_I",
            "ACTION REFILL_START_ADDR=REQ_ADDR_Q",
            "HOLD VALID UNTIL READY",
        ],
        "LOAD MISS",
    )
    canvas.box_text(
        1660,
        115,
        [
            "&& LINE_VALID && LINE_READY",
            "ACTION TAG_REFILL_VALID=1",
            "ACTION DATA_REFILL_VALID=1",
            "ACTION RSP_ERR_Q=LINE_ERROR",
        ],
        "REFILL ACCEPT",
    )
    canvas.box_text(
        890,
        920,
        [
            "&& REQ_WRITE",
            "ACTION STORE_START_ADDR=REQ_ADDR_Q",
            "ACTION STORE_START_WDATA=REQ_WDATA_Q",
            "ACTION STORE_HIT_Q=TAG_HIT_I",
        ],
        "STORE START",
    )
    canvas.box_text(
        1660,
        920,
        [
            "&& STORE_DONE_VALID",
            "&& STORE_DONE_READY",
            "&& STORE_HIT_Q",
            "&& !STORE_DONE_ERROR",
            "ACTION DATA_STORE_VALID=1",
        ],
        "STORE HIT UPDATE",
    )
    canvas.box_text(
        1880,
        360,
        [
            "LOAD: RSP_DATA = HIT OR REFILL WORD",
            "STORE: RSP_DATA = 0",
            "ERROR: INVALID OR REFILL/STORE ERROR",
            "HOLD UNTIL CORE_RSP_READY",
        ],
        "RESPONSE",
    )
    canvas.box_text(
        820,
        650,
        [
            "&& FLUSH_I",
            "ACTION STATE_Q = IDLE",
            "ACTION SUPPRESS RSP_VALID",
            "ACTION SUPPRESS UPDATE PULSES",
            "ACTION FORWARD REFILL/STORE FLUSH",
        ],
        "FLUSH PRIORITY",
    )

    canvas.action_label(60, 690, ["CORE_REQ_READY = IDLE && !FLUSH", "LOOKUP_VALID = CORE_REQ_VALID && IDLE"])
    canvas.action_label(1340, 380, ["REFILL_LINE_READY = LOAD_WAIT", "TAG ERROR = LINE_ERROR"])
    canvas.action_label(1340, 705, ["STORE_DONE_READY = STORE_WAIT", "STORE MISS DOES NOT ALLOCATE"])
    canvas.action_label(1680, 395, ["WORD_INDEX = REQ_ADDR_Q[3:2]", "SELECT REFILL WORD"])
    canvas.action_label(1680, 705, ["UPDATE ONLY STORE HIT", "AND DOWNSTREAM OK"])

    canvas.text(40, 1215, "NOTE: THIS PNG IS GENERATED BY DOCS/TOOLS/RENDER_STATE_PNGS.PY", scale=2, color=DARK_GRAY)
    canvas.write_png(Path("dcache/docs/images/dcache_ctrl_fsm.png"))


def main() -> None:
    diagrams = [
        (
            "frontend/docs/images/frontend_fetch_state.png",
            "FRONTEND_FETCH FSM",
            [
                Node("reset", 70, 220, 190, 90, ("SEQ", "CLK_I/RST_NI", "RESET IDLE"), BLUE),
                Node("idle", 340, 220, 210, 90, ("SEQ", "CLK_I/RST_NI", "IDLE"), GREEN),
                Node("local", 610, 70, 230, 90, ("COMB", "LOCAL FAULT", "MISALIGNED"), PINK),
                Node("wait", 610, 220, 230, 90, ("SEQ", "CLK_I/RST_NI", "WAIT_RSP"), YELLOW),
                Node("kill", 610, 380, 230, 90, ("SEQ", "CLK_I/RST_NI", "KILL"), PINK),
                Node("deliver", 950, 150, 220, 90, ("COMB", "DELIVER", "INSTR VALID"), GREEN),
                Node("drop", 950, 340, 220, 90, ("COMB", "DROP", "RSP READY"), GRAY),
            ],
            [
                Edge("reset", "idle", "RST RELEASE"),
                Edge("idle", "local", "PC_MISALIGNED & READY"),
                Edge("local", "idle", "SAME CYCLE"),
                Edge("idle", "wait", "REQ_VALID & REQ_READY"),
                Edge("wait", "deliver", "RSP_VALID & !KILL & !FLUSH"),
                Edge("deliver", "idle", "INSTR_READY"),
                Edge("wait", "kill", "FLUSH"),
                Edge("kill", "drop", "RSP_VALID"),
                Edge("drop", "idle", "CONSUMED"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "ONE OUTSTANDING REQUEST", "FLUSH KILLS OUTSTANDING RESPONSE", "MISALIGNED PC DOES NOT ISSUE MEMORY REQUEST"],
        ),
        (
            "frontend/docs/images/frontend_pc_state.png",
            "FRONTEND_PC STATE",
            [
                Node("reset", 70, 220, 190, 90, ("SEQ", "CLK_I/RST_NI", "RESET"), BLUE),
                Node("valid", 350, 220, 210, 90, ("SEQ", "CLK_I/RST_NI", "PC VALID"), GREEN),
                Node("advance", 650, 90, 220, 90, ("SEQ", "CLK_I/RST_NI", "PC=PC+4"), YELLOW),
                Node("hold", 650, 350, 220, 90, ("SEQ", "CLK_I/RST_NI", "HOLD"), GRAY),
                Node("redir", 960, 220, 220, 90, ("SEQ", "CLK_I/RST_NI", "PC=TARGET"), PINK),
            ],
            [
                Edge("reset", "valid", "RST RELEASE"),
                Edge("valid", "advance", "VALID & READY & !STALL"),
                Edge("advance", "valid", "NEXT"),
                Edge("valid", "hold", "STALL OR !READY"),
                Edge("hold", "valid", "UNSTALL/READY"),
                Edge("valid", "redir", "REDIRECT"),
                Edge("hold", "redir", "REDIRECT"),
                Edge("advance", "redir", "REDIRECT WINS"),
                Edge("redir", "valid", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "RESET HAS ASYNC PRIORITY", "RUNTIME PRIORITY: REDIRECT THEN FETCH_FIRE THEN HOLD", "MISALIGNED FLAG = OR(PC[1:0])"],
        ),
        (
            "frontend/docs/images/frontend_ibuf_state.png",
            "FRONTEND_IBUF REGISTER TRANSFER",
            [
                Node("reset", 60, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "RESET EMPTY"), BLUE),
                Node("empty", 340, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "COUNT=0"), GREEN),
                Node("one", 650, 230, 210, 90, ("SEQ", "CLK_I/RST_NI", "COUNT=1"), YELLOW),
                Node("full", 970, 230, 210, 90, ("SEQ", "CLK_I/RST_NI", "COUNT=DEPTH"), PINK),
                Node("flush", 650, 470, 230, 90, ("SEQ", "CLK_I/RST_NI", "FLUSH CLEAR"), GRAY),
                Node("comb", 650, 70, 260, 90, ("COMB", "READY VALID", "STATUS MUX"), GREEN),
            ],
            [
                Edge("reset", "empty", "RST RELEASE"),
                Edge("empty", "one", "PUSH_FIRE"),
                Edge("one", "empty", "POP_FIRE"),
                Edge("one", "full", "PUSH ONLY"),
                Edge("full", "one", "POP_ONLY"),
                Edge("one", "one", "PUSH&POP"),
                Edge("empty", "flush", "FLUSH"),
                Edge("one", "flush", "FLUSH"),
                Edge("full", "flush", "FLUSH"),
                Edge("flush", "empty", "NEXT"),
                Edge("comb", "empty", "EMPTY STATUS"),
                Edge("comb", "one", "DATA FROM RD_PTR"),
                Edge("comb", "full", "FULL STATUS"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "FLUSH CLEARS COUNT AND POINTERS", "PUSH_READY = !FULL && !FLUSH", "POP_VALID = !EMPTY && !FLUSH", "NO EMPTY SAME-CYCLE BYPASS"],
        ),
        (
            "frontend/docs/images/frontend_state.png",
            "FRONTEND TOP INTEGRATION",
            [
                Node("ctrl", 60, 220, 230, 110, ("IF", "BOOT STALL", "REDIRECT"), BLUE),
                Node("pc", 380, 220, 230, 110, ("SEQ", "CLK_I/RST_NI", "FRONTEND_PC"), GREEN),
                Node("fetch_comb", 690, 130, 250, 90, ("COMB", "FETCH", "REQ/RSP CTRL"), YELLOW),
                Node("fetch_seq", 690, 310, 250, 90, ("SEQ", "CLK_I/RST_NI", "FETCH STATE"), GREEN),
                Node("ibuf_comb", 1040, 130, 240, 90, ("COMB", "IBUF", "READY/DATA"), YELLOW),
                Node("ibuf_seq", 1040, 310, 240, 90, ("SEQ", "CLK_I/RST_NI", "IBUF FIFO"), GREEN),
                Node("core", 1370, 220, 220, 110, ("IF", "CORE SIDE", "INSTR RSP"), GREEN),
                Node("imem", 700, 460, 250, 100, ("IF", "IMEM_IF", "REQ/RSP"), GRAY),
                Node("flush", 1040, 60, 240, 100, ("COMB", "REDIRECT", "FLUSH FANOUT"), PINK),
            ],
            [
                Edge("ctrl", "pc", "BOOT STALL REDIR"),
                Edge("pc", "fetch_comb", "PC VALID/READY"),
                Edge("fetch_comb", "fetch_seq", "CAPTURE/KILL"),
                Edge("fetch_seq", "fetch_comb", "STATE"),
                Edge("fetch_comb", "ibuf_comb", "FETCH RSP"),
                Edge("ibuf_comb", "ibuf_seq", "PUSH/POP"),
                Edge("ibuf_seq", "ibuf_comb", "FIFO STATE"),
                Edge("ibuf_comb", "core", "INSTR VALID/READY"),
                Edge("fetch_comb", "imem", "REQ/RSP"),
                Edge("ctrl", "flush", "REDIRECT_VALID"),
                Edge("flush", "fetch_seq", "DROP STALE"),
                Edge("flush", "ibuf_seq", "CLEAR QUEUE"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "WRAPPER OWNS NO EXTRA REGISTERS", "REDIRECT RETARGETS PC AND FLUSHES FETCH/IBUF", "IMEM_IF CONNECTS TO LATER ICACHE"],
            1700,
            760,
        ),
        (
            "icache/docs/images/icache_tag_state.png",
            "ICACHE_TAG VALID TAG STATE",
            [
                Node("reset", 70, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "RESET INVALID"), BLUE),
                Node("invalid", 350, 230, 230, 90, ("SEQ", "CLK_I/RST_NI", "LINE INVALID"), GRAY),
                Node("valid", 700, 230, 230, 90, ("SEQ", "CLK_I/RST_NI", "LINE VALID"), GREEN),
                Node("lookup", 1040, 120, 240, 90, ("COMB", "LOOKUP", "TAG MATCH"), YELLOW),
                Node("miss", 1040, 340, 240, 90, ("COMB", "LOOKUP", "MISS"), PINK),
                Node("inv", 700, 500, 230, 90, ("SEQ", "CLK_I/RST_NI", "INVALIDATE"), PINK),
            ],
            [
                Edge("reset", "invalid", "RST RELEASE"),
                Edge("invalid", "valid", "REFILL OK"),
                Edge("valid", "invalid", "REFILL ERROR"),
                Edge("valid", "valid", "REFILL SAME/NEW TAG"),
                Edge("valid", "lookup", "VALID && TAG EQ"),
                Edge("invalid", "miss", "!VALID"),
                Edge("valid", "miss", "TAG NE"),
                Edge("valid", "inv", "INVALIDATE"),
                Edge("invalid", "inv", "INVALIDATE"),
                Edge("inv", "invalid", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "PRIORITY: RESET THEN INVALIDATE THEN REFILL", "REFILL_ERROR KEEPS LINE INVALID", "LOOKUP_HIT REQUIRES LOOKUP_VALID"],
        ),
        (
            "icache/docs/images/icache_data_state.png",
            "ICACHE_DATA LINE STORAGE",
            [
                Node("lookup_if", 60, 230, 210, 90, ("IF", "LOOKUP", "ADDR"), BLUE),
                Node("decode", 350, 120, 250, 90, ("COMB", "INDEX WORD", "DECODE"), YELLOW),
                Node("ram", 690, 230, 250, 100, ("SEQ", "CLK_I", "LINE RAM"), GREEN),
                Node("mux", 1030, 120, 240, 90, ("COMB", "LINE READ", "WORD MUX"), YELLOW),
                Node("rsp", 1320, 120, 210, 90, ("IF", "LOOKUP", "DATA OUT"), GREEN),
                Node("refill", 350, 430, 250, 90, ("IF", "REFILL", "LINE WRITE"), BLUE),
            ],
            [
                Edge("lookup_if", "decode", "ADDR"),
                Edge("decode", "ram", "INDEX"),
                Edge("ram", "mux", "LINE"),
                Edge("decode", "mux", "WORD OFFSET"),
                Edge("mux", "rsp", "WORD/LINE"),
                Edge("refill", "ram", "VALID LINE"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I", "RST_NI DOES NOT CLEAR DATA RAM", "TAG VALID BITS CONTROL DATA USABILITY", "WORD OFFSET ZERO SELECTS BITS 31:0"],
            1600,
            760,
        ),
        (
            "icache/docs/images/icache_refill_fsm.png",
            "ICACHE_REFILL L3 FSM",
            [
                Node("idle", 80, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "IDLE"), GREEN),
                Node("align", 340, 110, 250, 90, ("COMB", "ALIGN", "START FIRE"), YELLOW),
                Node("req", 360, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "REQ"), YELLOW),
                Node("reqc", 620, 300, 230, 90, ("COMB", "REQ", "ENCODER"), YELLOW),
                Node("wait", 900, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "WAIT"), YELLOW),
                Node("store", 900, 110, 250, 90, ("COMB", "STORE WORD", "ERR OR"), GREEN),
                Node("done", 1200, 300, 210, 90, ("SEQ", "CLK_I/RST_NI", "DONE"), GREEN),
                Node("line", 1470, 300, 220, 90, ("IF", "LINE", "VALID/READY"), GREEN),
                Node("flush", 650, 520, 230, 90, ("COMB", "FLUSH", "ABORT"), PINK),
            ],
            [
                Edge("idle", "align", "START_VALID"),
                Edge("align", "req", "CAPTURE BASE"),
                Edge("req", "reqc", "REQ_VALID"),
                Edge("reqc", "wait", "REQ_READY"),
                Edge("wait", "store", "RSP_VALID"),
                Edge("store", "req", "NOT LAST"),
                Edge("store", "done", "LAST BEAT"),
                Edge("done", "line", "LINE_VALID"),
                Edge("line", "idle", "LINE_READY"),
                Edge("req", "flush", "FLUSH"),
                Edge("wait", "flush", "FLUSH"),
                Edge("done", "flush", "FLUSH"),
                Edge("flush", "idle", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "REQ ENCODING: READ WORD INSTRUCTION", "STORE RESPONSE WORD AT CURRENT BEAT", "FLUSH ABORTS WITHOUT LINE_VALID"],
            1760,
            760,
        ),
        (
            "dcache/docs/images/dcache_tag_state.png",
            "DCACHE_TAG VALID TAG STATE",
            [
                Node("reset", 70, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "RESET INVALID"), BLUE),
                Node("invalid", 350, 230, 230, 90, ("SEQ", "CLK_I/RST_NI", "LINE INVALID"), GRAY),
                Node("valid", 700, 230, 230, 90, ("SEQ", "CLK_I/RST_NI", "LINE VALID"), GREEN),
                Node("lookup", 1040, 120, 240, 90, ("COMB", "LOOKUP", "TAG MATCH"), YELLOW),
                Node("miss", 1040, 340, 240, 90, ("COMB", "LOOKUP", "MISS"), PINK),
                Node("inv", 700, 500, 230, 90, ("SEQ", "CLK_I/RST_NI", "INVALIDATE"), PINK),
            ],
            [
                Edge("reset", "invalid", "RST RELEASE"),
                Edge("invalid", "valid", "REFILL OK"),
                Edge("valid", "invalid", "REFILL ERROR"),
                Edge("valid", "valid", "REFILL NEW TAG"),
                Edge("valid", "lookup", "VALID && TAG EQ"),
                Edge("invalid", "miss", "!VALID"),
                Edge("valid", "miss", "TAG NE"),
                Edge("valid", "inv", "INVALIDATE"),
                Edge("invalid", "inv", "INVALIDATE"),
                Edge("inv", "invalid", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "PRIORITY: RESET THEN INVALIDATE THEN REFILL", "REFILL_ERROR KEEPS LINE INVALID", "LOOKUP_HIT REQUIRES LOOKUP_VALID"],
        ),
        (
            "dcache/docs/images/dcache_data_state.png",
            "DCACHE_DATA LINE STORAGE",
            [
                Node("lookup_if", 50, 220, 210, 90, ("IF", "LOOKUP", "ADDR"), BLUE),
                Node("decode", 340, 110, 250, 90, ("COMB", "INDEX WORD", "DECODE"), YELLOW),
                Node("ram", 680, 220, 250, 100, ("SEQ", "CLK_I", "LINE RAM"), GREEN),
                Node("mux", 1020, 110, 240, 90, ("COMB", "LINE READ", "WORD MUX"), YELLOW),
                Node("rsp", 1320, 110, 210, 90, ("IF", "LOOKUP", "DATA OUT"), GREEN),
                Node("refill", 340, 420, 250, 90, ("IF", "REFILL", "LINE WRITE"), BLUE),
                Node("store_if", 50, 520, 210, 90, ("IF", "STORE", "ADDR DATA STRB"), BLUE),
                Node("merge", 680, 430, 250, 100, ("COMB", "STORE", "BYTE MERGE"), YELLOW),
                Node("prio", 1020, 430, 240, 90, ("COMB", "WRITE", "PRIORITY"), PINK),
            ],
            [
                Edge("lookup_if", "decode", "ADDR"),
                Edge("decode", "ram", "INDEX"),
                Edge("ram", "mux", "LINE"),
                Edge("decode", "mux", "WORD OFFSET"),
                Edge("mux", "rsp", "WORD/LINE"),
                Edge("refill", "prio", "FULL LINE"),
                Edge("store_if", "merge", "STORE HIT"),
                Edge("ram", "merge", "OLD LINE"),
                Edge("merge", "prio", "MERGED LINE"),
                Edge("prio", "ram", "REFILL > STORE"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I", "RST_NI DOES NOT CLEAR DATA RAM", "REFILL REPLACES WHOLE LINE", "STORE MERGES SELECTED BYTE LANES"],
            1600,
            760,
        ),
        (
            "dcache/docs/images/dcache_refill_fsm.png",
            "DCACHE_REFILL L3 FSM",
            [
                Node("idle", 80, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "IDLE"), GREEN),
                Node("align", 340, 110, 250, 90, ("COMB", "ALIGN", "START FIRE"), YELLOW),
                Node("req", 360, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "REQ"), YELLOW),
                Node("reqc", 620, 300, 230, 90, ("COMB", "REQ", "DATA READ"), YELLOW),
                Node("wait", 900, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "WAIT"), YELLOW),
                Node("store", 900, 110, 250, 90, ("COMB", "STORE WORD", "ERR OR"), GREEN),
                Node("done", 1200, 300, 210, 90, ("SEQ", "CLK_I/RST_NI", "DONE"), GREEN),
                Node("line", 1470, 300, 220, 90, ("IF", "LINE", "VALID/READY"), GREEN),
                Node("flush", 650, 520, 230, 90, ("COMB", "FLUSH", "ABORT"), PINK),
            ],
            [
                Edge("idle", "align", "START_VALID"),
                Edge("align", "req", "CAPTURE BASE"),
                Edge("req", "reqc", "REQ_VALID"),
                Edge("reqc", "wait", "REQ_READY"),
                Edge("wait", "store", "RSP_VALID"),
                Edge("store", "req", "NOT LAST"),
                Edge("store", "done", "LAST BEAT"),
                Edge("done", "line", "LINE_VALID"),
                Edge("line", "idle", "LINE_READY"),
                Edge("req", "flush", "FLUSH"),
                Edge("wait", "flush", "FLUSH"),
                Edge("done", "flush", "FLUSH"),
                Edge("flush", "idle", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "REQ ENCODING: READ WORD DATA, REQ_INSTR=0", "STORE RESPONSE WORD AT CURRENT BEAT", "FLUSH ABORTS WITHOUT LINE_VALID"],
            1760,
            760,
        ),
        (
            "dcache/docs/images/dcache_store_fsm.png",
            "DCACHE_STORE L3 FSM",
            [
                Node("idle", 70, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "IDLE"), GREEN),
                Node("capture", 330, 110, 270, 90, ("COMB", "START FIRE", "CAPTURE FIELDS"), YELLOW),
                Node("req", 360, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "REQ"), YELLOW),
                Node("reqc", 640, 300, 250, 90, ("COMB", "WRITE REQ", "ENCODER"), YELLOW),
                Node("wait", 940, 300, 190, 90, ("SEQ", "CLK_I/RST_NI", "WAIT"), YELLOW),
                Node("rspc", 940, 110, 250, 90, ("COMB", "RSP ERR", "CAPTURE"), PINK),
                Node("done", 1240, 300, 210, 90, ("SEQ", "CLK_I/RST_NI", "DONE"), GREEN),
                Node("done_if", 1510, 300, 230, 90, ("IF", "DONE", "VALID/READY"), GREEN),
                Node("mem_if", 640, 520, 250, 90, ("IF", "MEM", "REQ/RSP"), BLUE),
                Node("flush", 980, 520, 230, 90, ("COMB", "FLUSH", "ABORT"), PINK),
            ],
            [
                Edge("idle", "capture", "START_VALID"),
                Edge("capture", "req", "START_READY"),
                Edge("req", "reqc", "REQ_VALID"),
                Edge("reqc", "wait", "REQ_READY"),
                Edge("reqc", "mem_if", "WRITE DATA"),
                Edge("mem_if", "wait", "RSP PATH"),
                Edge("wait", "rspc", "RSP_VALID"),
                Edge("rspc", "done", "ERR CAPTURED"),
                Edge("done", "done_if", "DONE_VALID"),
                Edge("done_if", "idle", "DONE_READY"),
                Edge("req", "flush", "FLUSH"),
                Edge("wait", "flush", "FLUSH"),
                Edge("done", "flush", "FLUSH"),
                Edge("flush", "idle", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "REQ ENCODING: WRITE DATA, REQ_INSTR=0", "ADDR/SIZE/WDATA/WSTRB HELD UNTIL DONE", "FLUSH ABORTS WITHOUT DONE_VALID"],
            1820,
            760,
        ),
        (
            "dcache/docs/images/dcache_ctrl_fsm.png",
            "DCACHE_CTRL L3 LOAD STORE CONTROL FSM",
            [
                Node("idle", 70, 430, 170, 95, ("SEQ", "CLK_I/RST_NI", "IDLE"), GREEN),
                Node("class", 360, 230, 270, 100, ("COMB", "REQUEST", "CLASSIFY"), YELLOW),
                Node("lookup", 360, 590, 270, 100, ("IF", "TAG DATA", "LOOKUP"), BLUE),
                Node("lreq", 760, 230, 250, 95, ("SEQ", "CLK_I/RST_NI", "LOAD REFILL REQ"), YELLOW),
                Node("lwait", 1120, 230, 260, 95, ("SEQ", "CLK_I/RST_NI", "LOAD REFILL WAIT"), YELLOW),
                Node("refill", 1120, 30, 270, 100, ("COMB", "REFILL", "UPDATE WORD"), GREEN),
                Node("sreq", 760, 590, 250, 95, ("SEQ", "CLK_I/RST_NI", "STORE REQ"), YELLOW),
                Node("swait", 1120, 590, 260, 95, ("SEQ", "CLK_I/RST_NI", "STORE WAIT"), YELLOW),
                Node("store", 1120, 790, 270, 100, ("COMB", "STORE", "HIT UPDATE"), GREEN),
                Node("resp", 1540, 430, 190, 95, ("SEQ", "CLK_I/RST_NI", "RESP"), GREEN),
                Node("rspmux", 1540, 230, 250, 95, ("COMB", "RESPONSE", "DATA ERROR"), GREEN),
                Node("core", 1880, 430, 220, 95, ("IF", "CORE", "REQ/RSP"), BLUE),
                Node("flush", 770, 430, 250, 95, ("COMB", "FLUSH", "ABORT"), PINK),
            ],
            [
                Edge("idle", "class", "REQ_FIRE"),
                Edge("class", "lookup", "LOOKUP_ADDR"),
                Edge("lookup", "class", "TAG_HIT DATA_WORD"),
                Edge("class", "resp", "INVALID OR LOAD HIT"),
                Edge("class", "lreq", "LOAD MISS"),
                Edge("lreq", "lwait", "REFILL_START_READY"),
                Edge("lwait", "refill", "LINE_VALID"),
                Edge("refill", "resp", "WORD/ERR CAPTURE"),
                Edge("class", "sreq", "STORE"),
                Edge("sreq", "swait", "STORE_START_READY"),
                Edge("swait", "store", "STORE_DONE"),
                Edge("store", "resp", "ERR CAPTURE"),
                Edge("resp", "rspmux", "RSP_VALID"),
                Edge("rspmux", "core", "RSP_READY"),
                Edge("core", "idle", "NEXT REQ"),
                Edge("lreq", "flush", "FLUSH"),
                Edge("lwait", "flush", "FLUSH"),
                Edge("sreq", "flush", "FLUSH"),
                Edge("swait", "flush", "FLUSH"),
                Edge("resp", "flush", "FLUSH"),
                Edge("flush", "idle", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "LOAD MISS ALLOCATES THROUGH REFILL", "STORE MISS WRITES THROUGH WITHOUT ALLOCATE", "STORE HIT UPDATES DATA ONLY IF DONE && !ERROR", "FLUSH SUPPRESSES RESPONSE AND UPDATE"],
            2160,
            980,
        ),
        (
            "tile/docs/images/tile_state.png",
            "TILE TIMING AND STATE OWNERSHIP",
            [
                Node("boot", 40, 300, 220, 100, ("IF", "BOOT PC", "CLK/RST"), BLUE),
                Node("front_seq", 330, 300, 260, 110, ("SEQ", "CLK_I/RST_NI", "FRONTEND STATE"), GREEN),
                Node("if_comb", 670, 300, 260, 110, ("COMB", "INSTR STREAM", "IF WIRING"), YELLOW),
                Node("core_seq", 1010, 300, 270, 110, ("SEQ", "CLK_I/RST_NI", "CORE STATE"), GREEN),
                Node("obs", 1360, 300, 230, 110, ("IF", "COMMIT TRAP", "DEBUG OBS"), BLUE),
                Node("ic_ctrl", 330, 100, 260, 100, ("IF", "ICACHE", "FLUSH/INVALIDATE"), BLUE),
                Node("ic_seq", 670, 100, 270, 110, ("SEQ", "CLK_I/RST_NI", "ICACHE STATE"), GREEN),
                Node("imem", 1020, 100, 230, 110, ("IF", "IMEM_IF", "REQ/RSP"), BLUE),
                Node("redirect", 500, 500, 270, 100, ("COMB", "REDIRECT", "VALID/PC WIRING"), YELLOW),
                Node("irq", 1010, 500, 270, 100, ("IF", "TIMER/EXTERNAL", "IRQ"), BLUE),
                Node("d_comb", 1010, 680, 270, 110, ("COMB", "CORE DCACHE", "REQ/RSP WIRING"), YELLOW),
                Node("dc_seq", 1360, 680, 270, 110, ("SEQ", "CLK_I/RST_NI", "DCACHE STATE"), GREEN),
                Node("dmem", 1700, 680, 190, 110, ("IF", "DMEM_IF", "REQ/RSP"), BLUE),
                Node("dc_ctrl", 1360, 850, 270, 100, ("IF", "DCACHE", "FLUSH/INVALIDATE"), BLUE),
            ],
            [
                Edge("boot", "front_seq", "BOOT/CLK/RST"),
                Edge("front_seq", "if_comb", "INSTR VALID/READY"),
                Edge("if_comb", "core_seq", "PC/INSTR/FAULT"),
                Edge("core_seq", "redirect", "REDIRECT"),
                Edge("redirect", "front_seq", "VALID/PC", bend=(400, 540)),
                Edge("if_comb", "ic_seq", "FRONT IMEM_IF"),
                Edge("ic_ctrl", "ic_seq", "MAINTENANCE"),
                Edge("ic_seq", "imem", "DOWNSTREAM"),
                Edge("core_seq", "obs", "OBSERVATIONS"),
                Edge("irq", "core_seq", "PENDING"),
                Edge("core_seq", "d_comb", "LSU FIELDS"),
                Edge("d_comb", "dc_seq", "CORE_IF"),
                Edge("dc_ctrl", "dc_seq", "MAINTENANCE"),
                Edge("dc_seq", "dmem", "DOWNSTREAM"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE WIRING, IF=INTERFACE", "CLOCK DOMAIN: ALL SEQ BLOCKS USE CLK_I WITH RST_NI", "TILE WRAPPER OWNS NO REGISTERS OR FSM", "IMEM_IF AND DMEM_IF REMAIN INDEPENDENT", "CORE DCACHE REQ_INSTR IS TIED LOW"],
            1940,
            1130,
        ),
        (
            "core/docs/images/core_state.png",
            "CORE TOP WRAPPER",
            [
                Node("port", 50, 210, 190, 90, ("IF", "CORE PORTS"), BLUE),
                Node("core", 340, 170, 260, 170, ("COMB", "CORE WRAP", "PASS THROUGH"), GREEN),
                Node("dp_seq", 720, 90, 280, 100, ("SEQ", "CLK_I/RST_NI", "DATAPATH STATE"), YELLOW),
                Node("dp_comb", 720, 280, 280, 100, ("COMB", "DATAPATH", "DECODE/EXEC"), GREEN),
                Node("obs", 1060, 80, 180, 90, ("IF", "COMMIT/TRAP"), GRAY),
                Node("imem", 1060, 230, 180, 90, ("IF", "INSTR", "STREAM"), GRAY),
                Node("dmem", 1060, 370, 180, 90, ("IF", "DMEM", "V/R"), GRAY),
                Node("irq", 760, 500, 180, 90, ("IF", "IRQ", "TIMER/EXT"), PINK),
            ],
            [
                Edge("port", "core", "CLK RST"),
                Edge("core", "dp_seq", "CLK/RST"),
                Edge("core", "dp_comb", "PORTS"),
                Edge("dp_seq", "dp_comb", "REG STATE"),
                Edge("dp_comb", "dp_seq", "NEXT STATE"),
                Edge("dp_comb", "obs", "STATE OBS"),
                Edge("dp_comb", "imem", "INSTR/REDIRECT"),
                Edge("dp_comb", "dmem", "LOAD/STORE"),
                Edge("irq", "dp_comb", "PENDING"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CORE WRAPPER OWNS NO SEQUENTIAL STATE", "DATAPATH SEQ DOMAIN: CLK_I WITH RST_NI"],
        ),
        (
            "core/docs/images/core_pipe_state.png",
            "CORE_PIPE STATE",
            [
                Node("reset", 70, 120, 190, 90, ("SEQ", "CLK_I/RST_NI", "RESET"), BLUE),
                Node("stream", 340, 110, 230, 110, ("IF", "FRONTEND", "STREAM"), BLUE),
                Node("accept", 650, 110, 210, 110, ("COMB", "ACCEPT", "CTRL"), YELLOW),
                Node("id", 940, 110, 210, 110, ("SEQ", "CLK_I/RST_NI", "IF/ID"), YELLOW),
                Node("ex", 1220, 110, 210, 110, ("SEQ", "CLK_I/RST_NI", "EX/WB"), YELLOW),
                Node("flush", 600, 330, 260, 110, ("COMB", "REDIRECT", "FLUSH CTRL"), PINK),
                Node("bubble", 1030, 330, 240, 110, ("COMB", "BUBBLE", "CTRL"), PINK),
            ],
            [
                Edge("reset", "stream", "RST RELEASE"),
                Edge("stream", "accept", "VALID"),
                Edge("accept", "id", "INSTR FIRE"),
                Edge("id", "ex", "ADVANCE"),
                Edge("flush", "stream", "REDIRECT"),
                Edge("flush", "id", "INVALID"),
                Edge("bubble", "ex", "INVALID"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "FRONTEND OWNS FETCH PC", "REDIRECT HAS HIGHEST PRIORITY", "DECODE STALL HOLDS IF/ID", "FETCH STALL BLOCKS STREAM READY"],
        ),
        (
            "core/docs/images/core_csr_state.png",
            "CORE_CSR STATE",
            [
                Node("reset", 70, 120, 200, 100, ("SEQ", "CLK_I/RST_NI", "CSR RESET"), BLUE),
                Node("decode", 390, 40, 240, 90, ("COMB", "CSR DECODE", "MASKS"), YELLOW),
                Node("normal", 390, 190, 220, 100, ("SEQ", "CLK_I/RST_NI", "CSR REGS"), GREEN),
                Node("trap", 760, 90, 250, 120, ("SEQ", "CLK_I/RST_NI", "TRAP ENTRY"), PINK),
                Node("mret", 760, 280, 250, 110, ("SEQ", "CLK_I/RST_NI", "MRET"), YELLOW),
                Node("count", 380, 330, 250, 100, ("SEQ", "CLK_I/RST_NI", "COUNTERS"), GRAY),
            ],
            [
                Edge("reset", "normal", "RST RELEASE"),
                Edge("normal", "decode", "CSR OLD"),
                Edge("decode", "normal", "WRITE DATA"),
                Edge("normal", "trap", "TRAP_VALID"),
                Edge("normal", "mret", "MRET"),
                Edge("normal", "count", "EACH CLK"),
                Edge("trap", "normal", "NEXT"),
                Edge("mret", "normal", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "TRAP OVERRIDES MRET", "LEGAL CSR WRITES APPLY MASKS", "INSTRET INCREMENTS ON RETIRE"],
        ),
        (
            "core/docs/images/core_int_datapath_state.png",
            "CORE_INT_DATAPATH STATE",
            [
                Node("fetch", 40, 250, 190, 80, ("IF", "INSTR", "STREAM"), GREEN),
                Node("pipe", 270, 250, 190, 80, ("SEQ", "CLK_I/RST_NI", "CORE_PIPE"), YELLOW),
                Node("decode", 520, 110, 190, 80, ("COMB", "DECODE"), BLUE),
                Node("hazard", 520, 10, 190, 70, ("COMB", "HAZARD"), PINK),
                Node("reg", 520, 360, 190, 80, ("SEQ", "CLK_I/RST_NI", "REGFILE"), BLUE),
                Node("alu", 780, 180, 160, 80, ("COMB", "ALU"), YELLOW),
                Node("branch", 780, 330, 190, 80, ("COMB", "BRANCH"), GREEN),
                Node("lsu", 780, 500, 190, 80, ("COMB", "LSU"), YELLOW),
                Node("lsu_wait", 1010, 500, 190, 80, ("SEQ", "CLK_I/RST_NI", "LSU WAIT"), GREEN),
                Node("csr_comb", 750, 590, 210, 70, ("COMB", "CSR DECODE", "READ"), YELLOW),
                Node("csr_seq", 750, 690, 210, 70, ("SEQ", "CLK_I/RST_NI", "CSR REGS"), GREEN),
                Node("wb", 1260, 180, 160, 80, ("COMB", "WB"), GREEN),
                Node("suppress", 1240, 330, 190, 80, ("COMB", "SUPPRESS"), PINK),
                Node("redirect", 1240, 500, 190, 80, ("COMB", "REDIRECT"), PINK),
                Node("trap", 1240, 640, 190, 80, ("COMB", "TRAP"), PINK),
            ],
            [
                Edge("fetch", "pipe", "ACCEPT"),
                Edge("pipe", "decode", "EX_INSTR"),
                Edge("decode", "hazard", "ID VS EX"),
                Edge("hazard", "pipe", "STALL/BUBBLE"),
                Edge("decode", "reg", "RS ADDR"),
                Edge("reg", "alu", "OPERANDS"),
                Edge("reg", "branch", "CMP/JALR"),
                Edge("reg", "lsu", "BASE DATA"),
                Edge("reg", "csr_comb", "CSR WDATA"),
                Edge("decode", "alu", "OP IMM"),
                Edge("decode", "branch", "BR/JAL"),
                Edge("decode", "lsu", "LD/ST"),
                Edge("decode", "csr_comb", "CSR/SYS"),
                Edge("alu", "wb", "SUPPORTED"),
                Edge("lsu", "lsu_wait", "REQ FIRE"),
                Edge("lsu_wait", "wb", "RSP FIRE"),
                Edge("lsu", "suppress", "FAULT"),
                Edge("lsu_wait", "pipe", "STALL"),
                Edge("csr_comb", "csr_seq", "WRITE/TRAP"),
                Edge("csr_seq", "csr_comb", "CSR STATE"),
                Edge("csr_comb", "wb", "CSR RDATA"),
                Edge("csr_seq", "trap", "MTVEC/MEPC"),
                Edge("trap", "redirect", "TRAP/MRET/IRQ"),
                Edge("branch", "redirect", "TAKEN"),
                Edge("redirect", "pipe", "FLUSH"),
                Edge("redirect", "fetch", "TARGET TO FRONTEND"),
                Edge("decode", "suppress", "ILLEGAL/UNSUP"),
                Edge("suppress", "wb", "NO WRITE"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "SUPPORTED: ALU BRANCH LOAD STORE CSR TRAP IRQ LOAD-USE HAZARD", "DATA VALID/READY WAIT IS INTEGRATED; FULL FORWARDING MUX IS STAGED LATER"],
            1500,
            920,
        ),
        (
            "core/docs/images/core_regfile_state.png",
            "CORE_REGFILE STATE",
            [
                Node("reset", 90, 230, 190, 90, ("SEQ", "CLK_I/RST_NI", "RESET"), BLUE),
                Node("hold", 380, 230, 210, 90, ("SEQ", "CLK_I/RST_NI", "HOLD"), GRAY),
                Node("write", 700, 230, 220, 90, ("SEQ", "CLK_I/RST_NI", "WRITE"), GREEN),
                Node("bypass", 1010, 230, 190, 90, ("COMB", "BYPASS"), YELLOW),
            ],
            [
                Edge("reset", "hold", "RST RELEASE"),
                Edge("hold", "write", "WE & RD!=0"),
                Edge("write", "hold", "NEXT"),
                Edge("write", "bypass", "READ MATCH"),
                Edge("bypass", "hold", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "X0 IS NOT STORED", "READ PRIORITY IS X0 THEN BYPASS THEN ARRAY"],
        ),
        (
            "dma/docs/images/ahb_dma_fsm.png",
            "AHB_DMA FSM",
            [
                Node("idle", 70, 230, 180, 90, ("SEQ", "HCLK/RSTN", "IDLE"), GREEN),
                Node("ra", 330, 120, 190, 90, ("SEQ", "HCLK/RSTN", "READ ADDR"), YELLOW),
                Node("rd", 610, 120, 190, 90, ("SEQ", "HCLK/RSTN", "READ DATA"), YELLOW),
                Node("wa", 610, 330, 190, 90, ("SEQ", "HCLK/RSTN", "WRITE ADDR"), YELLOW),
                Node("wr", 330, 330, 190, 90, ("SEQ", "HCLK/RSTN", "WRITE RESP"), YELLOW),
                Node("err", 900, 230, 190, 90, ("SEQ", "HCLK/RSTN", "ERROR"), PINK),
                Node("done", 900, 380, 190, 90, ("SEQ", "HCLK/RSTN", "DONE"), GREEN),
            ],
            [
                Edge("idle", "ra", "START OK"),
                Edge("idle", "err", "BAD START"),
                Edge("ra", "rd", "HREADY"),
                Edge("rd", "wa", "OKAY"),
                Edge("rd", "err", "ERROR"),
                Edge("wa", "wr", "HREADY"),
                Edge("wr", "ra", "MORE"),
                Edge("wr", "done", "LAST"),
                Edge("wr", "err", "ERROR"),
                Edge("done", "idle", "CLEAR"),
                Edge("err", "idle", "CLEAR"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "ONE WORD READ THEN ONE WORD WRITE", "NO BURSTS", "DONE OR ERROR CAN ASSERT IRQ"],
        ),
        (
            "uart/docs/images/ahb_uart_state.png",
            "AHB_UART STATE",
            [
                Node("reset", 70, 230, 180, 90, ("SEQ", "HCLK/RSTN", "RESET"), BLUE),
                Node("reg", 330, 230, 210, 90, ("SEQ", "HCLK/RSTN", "AHB REG"), GRAY),
                Node("tx", 640, 120, 210, 90, ("SEQ", "HCLK/RSTN", "TX FIFO"), GREEN),
                Node("rx", 640, 340, 210, 90, ("SEQ", "HCLK/RSTN", "RX FIFO"), GREEN),
                Node("irq", 960, 230, 210, 90, ("SEQ", "HCLK/RSTN", "IRQ_STATUS"), PINK),
            ],
            [
                Edge("reset", "reg", "RST RELEASE"),
                Edge("reg", "tx", "DATA WRITE"),
                Edge("tx", "irq", "TX EMPTY"),
                Edge("reg", "rx", "RX VALID"),
                Edge("rx", "irq", "RX AVAIL"),
                Edge("irq", "reg", "W1C/NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "SERIAL BIT FSM IS IN UART_TX AND UART_RX", "AHB PATH IS ONE CYCLE RESPONSE"],
        ),
        (
            "uart/docs/images/uart_rx_fsm.png",
            "UART_RX FSM",
            [
                Node("idle", 80, 230, 180, 90, ("SEQ", "CLK_I/RST_NI", "RX_IDLE"), GREEN),
                Node("start", 350, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "RX_START"), YELLOW),
                Node("data", 640, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "RX_DATA"), YELLOW),
                Node("stop", 930, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "RX_STOP"), YELLOW),
                Node("valid", 930, 420, 200, 80, ("SEQ", "CLK_I/RST_NI", "VALID"), GREEN),
                Node("err", 640, 420, 200, 80, ("SEQ", "CLK_I/RST_NI", "FRAME_ERR"), PINK),
            ],
            [
                Edge("idle", "start", "RX=0"),
                Edge("start", "data", "TICK & LOW"),
                Edge("start", "idle", "FALSE"),
                Edge("data", "stop", "BIT7"),
                Edge("stop", "valid", "STOP=1"),
                Edge("stop", "err", "STOP=0"),
                Edge("valid", "idle", "NEXT"),
                Edge("err", "idle", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "RESET OR DISABLE RETURNS TO RX_IDLE", "DATA IS SAMPLED LSB FIRST"],
        ),
        (
            "uart/docs/images/uart_tx_state.png",
            "UART_TX STATE",
            [
                Node("idle", 120, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "TX_IDLE"), GREEN),
                Node("load", 450, 230, 200, 90, ("SEQ", "CLK_I/RST_NI", "LOAD"), YELLOW),
                Node("shift", 780, 230, 220, 90, ("SEQ", "CLK_I/RST_NI", "TX_SHIFT"), YELLOW),
                Node("done", 780, 420, 220, 80, ("SEQ", "CLK_I/RST_NI", "DONE"), GREEN),
            ],
            [
                Edge("idle", "load", "VALID"),
                Edge("load", "shift", "BUSY"),
                Edge("shift", "shift", "TICK & MORE", bend=(1030, 170)),
                Edge("shift", "done", "LAST BIT"),
                Edge("done", "idle", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "DISABLE FORCES TX_IDLE", "FRAME IS START DATA STOP", "DATA SHIFTS LSB FIRST"],
        ),
        (
            "uart/docs/images/uart_baud_counter_state.png",
            "UART_BAUD COUNTER",
            [
                Node("reset", 110, 230, 180, 90, ("SEQ", "CLK_I/RST_NI", "RESET"), BLUE),
                Node("disabled", 400, 230, 210, 90, ("SEQ", "CLK_I/RST_NI", "DISABLED"), GRAY),
                Node("count", 710, 230, 210, 90, ("SEQ", "CLK_I/RST_NI", "COUNT"), YELLOW),
                Node("tick", 1010, 230, 170, 90, ("SEQ", "CLK_I/RST_NI", "TICK"), GREEN),
            ],
            [
                Edge("reset", "disabled", "RST RELEASE"),
                Edge("disabled", "count", "ENABLE"),
                Edge("count", "tick", "TERM"),
                Edge("tick", "count", "NEXT"),
                Edge("count", "disabled", "DISABLE"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: CLK_I WITH RST_NI", "DIVISOR ZERO MAPS TO ONE", "TICK IS ONE CLOCK CYCLE"],
        ),
        (
            "otp/docs/images/ahb_otp_state.png",
            "AHB_OTP PROGRAM STATE",
            [
                Node("erased", 80, 220, 190, 90, ("SEQ", "HCLK/RSTN", "ERASED"), GREEN),
                Node("locked", 360, 100, 190, 90, ("SEQ", "HCLK/RSTN", "LOCKED"), PINK),
                Node("armed", 360, 340, 190, 90, ("SEQ", "HCLK/RSTN", "ARMED"), YELLOW),
                Node("prog", 660, 340, 210, 90, ("SEQ", "HCLK/RSTN", "PROGRAM"), YELLOW),
                Node("done", 960, 250, 180, 90, ("SEQ", "HCLK/RSTN", "DONE"), GREEN),
                Node("err", 660, 100, 210, 90, ("SEQ", "HCLK/RSTN", "ERROR"), PINK),
            ],
            [
                Edge("erased", "armed", "KEY"),
                Edge("armed", "prog", "START OK"),
                Edge("prog", "done", "1 TO 0"),
                Edge("armed", "err", "BAD REQ"),
                Edge("locked", "err", "START"),
                Edge("armed", "locked", "LOCK"),
                Edge("done", "armed", "CLEAR"),
                Edge("err", "armed", "CLEAR"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "OPEN RTL PROGRAMS IN ONE RESPONSE CYCLE", "0 TO 1 REQUEST IS REJECTED"],
        ),
        (
            "timer/docs/images/ahb_timer_state.png",
            "AHB_TIMER STATE",
            [
                Node("reset", 80, 230, 190, 90, ("SEQ", "HCLK/RSTN", "RESET"), BLUE),
                Node("disabled", 360, 230, 220, 90, ("SEQ", "HCLK/RSTN", "DISABLED"), GRAY),
                Node("enabled", 690, 230, 220, 90, ("SEQ", "HCLK/RSTN", "ENABLED"), YELLOW),
                Node("pending", 1000, 230, 190, 90, ("SEQ", "HCLK/RSTN", "PENDING"), PINK),
            ],
            [
                Edge("reset", "disabled", "RST RELEASE"),
                Edge("disabled", "enabled", "CTRL.EN"),
                Edge("enabled", "disabled", "CTRL.DIS"),
                Edge("enabled", "pending", "MTIME>=CMP"),
                Edge("pending", "enabled", "CMP FUTURE"),
                Edge("pending", "disabled", "DISABLE"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "IRQ = PENDING AND IRQ_ENABLE", "SOFTWARE CLEARS BY FUTURE MTIMECMP"],
        ),
        (
            "gpio/docs/images/ahb_gpio_state.png",
            "AHB_GPIO IRQ STATE",
            [
                Node("sync", 90, 210, 210, 90, ("SEQ", "HCLK/RSTN", "INPUT SYNC"), BLUE),
                Node("detect", 390, 210, 220, 90, ("COMB", "DETECT", "LEVEL EDGE"), YELLOW),
                Node("latched", 700, 210, 220, 90, ("SEQ", "HCLK/RSTN", "IRQ_STATUS"), PINK),
                Node("clear", 1010, 210, 180, 90, ("SEQ", "HCLK/RSTN", "W1C CLEAR"), GREEN),
            ],
            [
                Edge("sync", "detect", "SAMPLE"),
                Edge("detect", "latched", "ENABLED HIT"),
                Edge("latched", "clear", "WRITE 1"),
                Edge("clear", "detect", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "DATA_OUT/DIR ARE NORMAL REGISTERS", "GPIO_IRQ_O IS OR OF ENABLED STATUS"],
        ),
        (
            "intc/docs/images/ahb_intc_state.png",
            "AHB_INTC STATE",
            [
                Node("sync", 80, 230, 190, 90, ("SEQ", "HCLK/RSTN", "IRQ SYNC"), BLUE),
                Node("pend", 350, 230, 210, 90, ("SEQ", "HCLK/RSTN", "PENDING"), PINK),
                Node("best", 650, 230, 220, 90, ("COMB", "BEST SRC"), YELLOW),
                Node("claim", 960, 150, 190, 90, ("SEQ", "HCLK/RSTN", "CLAIM"), GREEN),
                Node("comp", 960, 330, 190, 90, ("SEQ", "HCLK/RSTN", "COMPLETE"), GREEN),
            ],
            [
                Edge("sync", "pend", "HIGH"),
                Edge("pend", "best", "ENABLE"),
                Edge("best", "claim", "READ"),
                Edge("claim", "comp", "WRITE ID"),
                Edge("comp", "pend", "CLEAR"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "LOWEST ID WINS TIES", "MEIP ASSERTS WHEN BEST SOURCE EXISTS"],
        ),
        (
            "bus/docs/images/ahb_fabric_2m_state.png",
            "AHB_FABRIC_2M STATE",
            [
                Node("reset", 60, 230, 180, 90, ("SEQ", "HCLK/RSTN", "RESET"), BLUE),
                Node("grant_seq", 300, 130, 230, 90, ("SEQ", "HCLK/RSTN", "GRANT STATE"), YELLOW),
                Node("grant_comb", 300, 340, 230, 90, ("COMB", "GRANT/ROUTE"), GREEN),
                Node("decode", 620, 230, 210, 90, ("COMB", "DECODER"), GREEN),
                Node("slave", 920, 120, 220, 90, ("IF", "SLAVE RESP"), GREEN),
                Node("def", 920, 340, 220, 90, ("COMB", "DEFAULT"), PINK),
            ],
            [
                Edge("reset", "grant_seq", "RST RELEASE"),
                Edge("grant_seq", "grant_comb", "HELD GRANT"),
                Edge("grant_comb", "grant_seq", "NEXT GRANT"),
                Edge("grant_comb", "decode", "ADDR"),
                Edge("decode", "slave", "MAPPED"),
                Edge("decode", "def", "UNMAPPED"),
                Edge("slave", "grant_comb", "RESP", bend=(760, 80)),
                Edge("def", "grant_comb", "RESP", bend=(760, 560)),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "FABRIC STATE IS COMPOSED FROM ARBITER STATE", "HREADY LOW HOLDS GRANT"],
        ),
        (
            "bus/docs/images/ahb_arbiter_2m_state.png",
            "AHB_ARBITER_2M GRANT STATE",
            [
                Node("reset", 80, 220, 190, 90, ("SEQ", "HCLK/RSTN", "RESET"), BLUE),
                Node("idle", 350, 220, 190, 90, ("SEQ", "HCLK/RSTN", "IDLE"), GRAY),
                Node("m0", 650, 120, 190, 90, ("SEQ", "HCLK/RSTN", "GRANT M0"), GREEN),
                Node("m1", 650, 340, 190, 90, ("SEQ", "HCLK/RSTN", "GRANT M1"), GREEN),
                Node("hold", 960, 230, 190, 90, ("SEQ", "HCLK/RSTN", "HOLD"), YELLOW),
            ],
            [
                Edge("reset", "idle", "RST RELEASE"),
                Edge("idle", "m0", "M0 REQ"),
                Edge("idle", "m1", "M1 REQ"),
                Edge("m0", "m1", "BOTH RR"),
                Edge("m1", "m0", "BOTH RR"),
                Edge("m0", "hold", "STALL"),
                Edge("m1", "hold", "STALL"),
                Edge("hold", "m0", "READY M0"),
                Edge("hold", "m1", "READY M1"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "LAST_GRANT_Q PROVIDES ROUND ROBIN", "RESPONSE ROUTING FOLLOWS HELD GRANT"],
        ),
        (
            "sram/docs/images/ahb_sram_state.png",
            "AHB_SRAM RESPONSE STATE",
            [
                Node("idle", 100, 230, 190, 90, ("SEQ", "HCLK/RSTN", "IDLE"), GRAY),
                Node("cap", 390, 230, 220, 90, ("SEQ", "HCLK/RSTN", "CAPTURE"), BLUE),
                Node("read", 710, 120, 210, 90, ("COMB", "READ RESP"), GREEN),
                Node("write_seq", 700, 340, 230, 90, ("SEQ", "HCLK/RSTN", "WRITE ARRAY"), GREEN),
                Node("write_comb", 1010, 340, 230, 90, ("COMB", "WRITE OKAY", "RESP"), GREEN),
                Node("err", 1010, 230, 170, 90, ("COMB", "ERROR RESP"), PINK),
            ],
            [
                Edge("idle", "cap", "SELECTED"),
                Edge("cap", "read", "READ OK"),
                Edge("cap", "write_seq", "WRITE OK"),
                Edge("cap", "err", "BAD XFER"),
                Edge("read", "idle", "NEXT"),
                Edge("write_seq", "write_comb", "RESP"),
                Edge("write_comb", "idle", "NEXT"),
                Edge("err", "idle", "NEXT"),
            ],
            ["LEGEND: SEQ=CLOCKED STATE, COMB=STATE-FREE LOGIC, IF=INTERFACE", "CLOCK DOMAIN: HCLK_I WITH HRESETN_I", "ONE CYCLE AHB RESPONSE MODEL", "HREADY IS ALWAYS HIGH"],
        ),
    ]
    for args in diagrams:
        render(*args)
    render_core_pipe_l3()
    render_ahb_dma_l3()
    render_icache_ctrl_l3()
    render_dcache_ctrl_l3()


if __name__ == "__main__":
    main()
