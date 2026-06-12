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

    def state(self, x: int, y: int, w: int, h: int, lines: tuple[str, ...], fill: Color = WHITE) -> None:
        self.ellipse(x, y, w, h, fill, BLACK, 2)
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
        canvas.rect(node.x, node.y, node.w, node.h, node.fill)
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
    canvas.text(40, 34, "CORE_PIPE L3 PIPELINE STATE / PRIORITY", scale=3, color=BLACK)
    canvas.box_text(
        40,
        90,
        [
            "GREEN TEXT : JUMP CONDITION",
            "GRAY BOX   : REGISTER ACTION",
            "PRIORITY   : REDIRECT > BUBBLE > ADVANCE",
        ],
        "LEGEND",
    )

    canvas.state(130, 320, 140, 90, ("RESET",), BLUE)
    canvas.state(420, 300, 180, 110, ("FETCH", "REQ"), GREEN)
    canvas.state(760, 300, 190, 110, ("IF/ID", "SLOT"), YELLOW)
    canvas.state(1120, 300, 190, 110, ("EX/WB", "SLOT"), YELLOW)
    canvas.state(780, 620, 220, 110, ("REDIRECT", "FLUSH"), PINK)
    canvas.state(1190, 620, 220, 110, ("EXEC", "BUBBLE"), PINK)
    canvas.state(1500, 300, 190, 110, ("HOLD", "STALL"), GRAY)

    canvas.path_arrow([(270, 365), (420, 355)], "RST_N=1")
    canvas.path_arrow([(600, 355), (760, 355)], "FETCH_FIRE")
    canvas.path_arrow([(950, 355), (1120, 355)], "ADVANCE")
    canvas.path_arrow([(1500, 355), (1310, 355)], "STALL RELEASE")
    canvas.path_arrow([(870, 620), (870, 410)], "FLUSH IF/ID")
    canvas.path_arrow([(890, 620), (1190, 410)], "FLUSH EX/WB")
    canvas.path_arrow([(1000, 675), (420, 410)], "PC TARGET")
    canvas.path_arrow([(1300, 620), (1230, 410)], "CLEAR EX/WB")
    canvas.path_arrow([(760, 320), (600, 215), (1500, 320)], "DECODE_STALL")
    canvas.path_arrow([(1120, 390), (1030, 520), (1500, 390)], "FETCH_STALL")

    canvas.box_text(
        620,
        120,
        [
            "&& IF_RSP_VALID_I",
            "&& !FETCH_STALL_I",
            "&& !DECODE_STALL_I",
            "&& !REDIRECT_VALID_I",
            "ACTION IF/ID <= RSP",
            "ACTION FETCH_PC += 4",
        ],
        "FETCH_FIRE",
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
            "ACTION FETCH_PC <= REDIRECT_PC_I",
            "ACTION IF/ID <= INVALID NOP",
            "ACTION EX/WB <= INVALID NOP",
        ],
        "HIGHEST PRIORITY",
    )
    canvas.box_text(
        1400,
        660,
        [
            "&& EXECUTE_BUBBLE_I",
            "&& !REDIRECT_VALID_I",
            "ACTION EX/WB <= INVALID NOP",
            "NOTE IF/ID HOLDS IF DECODE_STALL_I",
        ],
        "LOAD USE BUBBLE",
    )
    canvas.action_label(420, 440, ["IF_REQ_VALID = !FETCH_STALL", "IF_RSP_READY = FETCH_ACCEPT"])
    canvas.action_label(755, 440, ["ID_VALID/PC/INSTR/FAULT", "CAPTURED FROM FETCH RESPONSE"])
    canvas.action_label(1115, 440, ["EX_VALID/PC/INSTR/FAULT", "CAPTURED FROM OLD IF/ID"])
    canvas.action_label(1480, 440, ["HOLD PC AND SLOTS", "NO RESPONSE ACCEPT"])

    canvas.text(40, 985, "NOTE: THIS PNG IS GENERATED BY DOCS/TOOLS/RENDER_STATE_PNGS.PY", scale=2, color=DARK_GRAY)
    canvas.write_png(Path("core/docs/images/core_pipe_state.png"))


def render_ahb_dma_l3() -> None:
    canvas = Canvas(2100, 1200)
    canvas.grid()
    canvas.text(40, 34, "AHB_DMA L3 CONTROL FSM", scale=3, color=BLACK)
    canvas.box_text(
        40,
        90,
        [
            "GREEN TEXT : JUMP CONDITION",
            "GRAY BOX   : REGISTER ACTION",
            "ERROR PATH : HRESP ERROR OR BAD START",
        ],
        "LEGEND",
    )

    canvas.state(110, 500, 140, 90, ("IDLE",), GREEN)
    canvas.state(430, 230, 210, 100, ("READ", "ADDR"), YELLOW)
    canvas.state(780, 230, 210, 100, ("READ", "DATA"), YELLOW)
    canvas.state(780, 690, 210, 100, ("WRITE", "ADDR"), YELLOW)
    canvas.state(430, 690, 210, 100, ("WRITE", "RESP"), YELLOW)
    canvas.state(1190, 460, 170, 100, ("DONE",), GREEN)
    canvas.state(1190, 640, 170, 100, ("ERROR",), PINK)
    canvas.state(1540, 540, 190, 100, ("IRQ", "STATUS"), GRAY)

    canvas.path_arrow([(250, 545), (430, 280)], "START OK")
    canvas.path_arrow([(640, 280), (780, 280)], "ADDR ACCEPT")
    canvas.path_arrow([(885, 330), (885, 690)], "READ OK")
    canvas.path_arrow([(780, 740), (640, 740)], "ADDR ACCEPT")
    canvas.path_arrow([(430, 740), (250, 545)], "MORE")
    canvas.path_arrow([(640, 740), (1190, 510)], "LAST OK")
    canvas.path_arrow([(990, 280), (1190, 690)], "READ ERR")
    canvas.path_arrow([(780, 760), (1190, 690)], "WRITE ERR")
    canvas.path_arrow([(250, 560), (1190, 690)], "BAD START")
    canvas.path_arrow([(1360, 510), (1540, 575)], "DONE IRQ")
    canvas.path_arrow([(1360, 690), (1540, 605)], "ERR IRQ")
    canvas.path_arrow([(1190, 510), (970, 1010), (110, 590)], "CTRL CLEAR")
    canvas.path_arrow([(1190, 690), (970, 1080), (110, 590)], "CTRL CLEAR")

    canvas.box_text(
        260,
        370,
        [
            "&& STATE == IDLE",
            "&& CTRL.START",
            "&& LEN_Q != 0",
            "&& SRC_Q[1:0] == 0",
            "&& DST_Q[1:0] == 0",
            "ACTION BUSY=1",
            "ACTION REMAINING=LEN_Q",
        ],
        "START ACCEPT",
    )
    canvas.box_text(
        670,
        85,
        [
            "ACTION M_HTRANS=NONSEQ",
            "ACTION M_HWRITE=0",
            "ACTION M_HADDR=CUR_SRC",
            "&& M_HREADY",
        ],
        "READ ADDRESS",
    )
    canvas.box_text(
        1010,
        190,
        [
            "&& M_HREADY",
            "&& M_HRESP == OKAY",
            "ACTION READ_DATA_Q <= M_HRDATA",
            "OR M_HRESP == ERROR -> ERROR",
        ],
        "READ RESPONSE",
    )
    canvas.box_text(
        1010,
        770,
        [
            "ACTION M_HTRANS=NONSEQ",
            "ACTION M_HWRITE=1",
            "ACTION M_HADDR=CUR_DST",
            "ACTION M_HWDATA=READ_DATA_Q",
            "&& M_HREADY",
        ],
        "WRITE ADDRESS",
    )
    canvas.box_text(
        260,
        830,
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
        1230,
        820,
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
        1410,
        700,
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
    canvas.action_label(1450, 470, ["DMA_IRQ_O = IRQ_ENABLE", "&& (DONE || ERROR)"])
    canvas.action_label(70, 665, ["SLAVE AHB REG PATH:", "CAPTURE N", "RESPOND N+1"])
    canvas.text(40, 1100, "NOTE: THIS PNG IS GENERATED BY DOCS/TOOLS/RENDER_STATE_PNGS.PY", scale=2, color=DARK_GRAY)
    canvas.write_png(Path("dma/docs/images/ahb_dma_fsm.png"))


def main() -> None:
    diagrams = [
        (
            "core/docs/images/core_pipe_state.png",
            "CORE_PIPE STATE",
            [
                Node("reset", 70, 120, 190, 90, ("RESET", "BOOT PC"), BLUE),
                Node("fetch", 340, 110, 210, 110, ("FETCH", "PC REQUEST"), GREEN),
                Node("id", 650, 110, 210, 110, ("IF/ID", "PC INSTR FLT"), YELLOW),
                Node("ex", 950, 110, 210, 110, ("EX/WB", "PC INSTR FLT"), YELLOW),
                Node("flush", 500, 330, 260, 110, ("REDIRECT", "FLUSH SLOTS"), PINK),
                Node("bubble", 860, 330, 240, 110, ("BUBBLE", "CLEAR EX/WB"), PINK),
            ],
            [
                Edge("reset", "fetch", "RST RELEASE"),
                Edge("fetch", "id", "FETCH FIRE"),
                Edge("id", "ex", "ADVANCE"),
                Edge("flush", "fetch", "PC=TARGET"),
                Edge("flush", "id", "INVALID"),
                Edge("bubble", "ex", "INVALID"),
            ],
            ["REDIRECT HAS HIGHEST PRIORITY", "DECODE STALL HOLDS IF/ID", "FETCH STALL BLOCKS REQUEST/READY"],
        ),
        (
            "core/docs/images/core_csr_state.png",
            "CORE_CSR STATE",
            [
                Node("reset", 70, 120, 200, 100, ("RESET", "CSR DEFAULTS"), BLUE),
                Node("normal", 390, 120, 220, 100, ("NORMAL", "CSR WRITE"), GREEN),
                Node("trap", 760, 90, 250, 120, ("TRAP ENTRY", "SAVE MIE MEPC", "CAUSE TVAL"), PINK),
                Node("mret", 760, 280, 250, 110, ("MRET", "RESTORE MIE"), YELLOW),
                Node("count", 380, 330, 250, 100, ("COUNTERS", "CYCLE INSTRET"), GRAY),
            ],
            [
                Edge("reset", "normal", "RST RELEASE"),
                Edge("normal", "trap", "TRAP_VALID"),
                Edge("normal", "mret", "MRET"),
                Edge("normal", "count", "EACH CLK"),
                Edge("trap", "normal", "NEXT"),
                Edge("mret", "normal", "NEXT"),
            ],
            ["TRAP OVERRIDES MRET", "LEGAL CSR WRITES APPLY MASKS", "INSTRET INCREMENTS ON RETIRE"],
        ),
        (
            "core/docs/images/core_regfile_state.png",
            "CORE_REGFILE STATE",
            [
                Node("reset", 90, 230, 190, 90, ("RESET", "X1-X31=0"), BLUE),
                Node("hold", 380, 230, 210, 90, ("HOLD", "NO WRITE"), GRAY),
                Node("write", 700, 230, 220, 90, ("WRITE", "RD!=X0"), GREEN),
                Node("bypass", 1010, 230, 190, 90, ("BYPASS", "SAME CYCLE"), YELLOW),
            ],
            [
                Edge("reset", "hold", "RST RELEASE"),
                Edge("hold", "write", "WE & RD!=0"),
                Edge("write", "hold", "NEXT"),
                Edge("write", "bypass", "READ MATCH"),
                Edge("bypass", "hold", "NEXT"),
            ],
            ["X0 IS NOT STORED", "READ PRIORITY IS X0 THEN BYPASS THEN ARRAY"],
        ),
        (
            "dma/docs/images/ahb_dma_fsm.png",
            "AHB_DMA FSM",
            [
                Node("idle", 70, 230, 180, 90, ("IDLE", "BUSY=0"), GREEN),
                Node("ra", 330, 120, 190, 90, ("READ", "ADDR"), YELLOW),
                Node("rd", 610, 120, 190, 90, ("READ", "DATA"), YELLOW),
                Node("wa", 610, 330, 190, 90, ("WRITE", "ADDR"), YELLOW),
                Node("wr", 330, 330, 190, 90, ("WRITE", "RESP"), YELLOW),
                Node("err", 900, 230, 190, 90, ("ERROR", "STICKY"), PINK),
                Node("done", 900, 380, 190, 90, ("DONE", "IRQ"), GREEN),
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
            ["ONE WORD READ THEN ONE WORD WRITE", "NO BURSTS", "DONE OR ERROR CAN ASSERT IRQ"],
        ),
        (
            "uart/docs/images/ahb_uart_state.png",
            "AHB_UART STATE",
            [
                Node("reset", 70, 230, 180, 90, ("RESET", "FIFO EMPTY"), BLUE),
                Node("reg", 330, 230, 210, 90, ("AHB REG", "CAPTURE RESP"), GRAY),
                Node("tx", 640, 120, 210, 90, ("TX FIFO", "POP TO TX"), GREEN),
                Node("rx", 640, 340, 210, 90, ("RX FIFO", "PUSH RX"), GREEN),
                Node("irq", 960, 230, 210, 90, ("IRQ_STATUS", "LATCH W1C"), PINK),
            ],
            [
                Edge("reset", "reg", "RST RELEASE"),
                Edge("reg", "tx", "DATA WRITE"),
                Edge("tx", "irq", "TX EMPTY"),
                Edge("reg", "rx", "RX VALID"),
                Edge("rx", "irq", "RX AVAIL"),
                Edge("irq", "reg", "W1C/NEXT"),
            ],
            ["SERIAL BIT FSM IS IN UART_TX AND UART_RX", "AHB PATH IS ONE CYCLE RESPONSE"],
        ),
        (
            "uart/docs/images/uart_rx_fsm.png",
            "UART_RX FSM",
            [
                Node("idle", 80, 230, 180, 90, ("RX_IDLE", "WAIT LOW"), GREEN),
                Node("start", 350, 230, 200, 90, ("RX_START", "CONFIRM"), YELLOW),
                Node("data", 640, 230, 200, 90, ("RX_DATA", "8 BITS"), YELLOW),
                Node("stop", 930, 230, 200, 90, ("RX_STOP", "CHECK HIGH"), YELLOW),
                Node("valid", 930, 420, 200, 80, ("VALID", "PULSE"), GREEN),
                Node("err", 640, 420, 200, 80, ("FRAME_ERR", "PULSE"), PINK),
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
            ["RESET OR DISABLE RETURNS TO RX_IDLE", "DATA IS SAMPLED LSB FIRST"],
        ),
        (
            "uart/docs/images/uart_tx_state.png",
            "UART_TX STATE",
            [
                Node("idle", 120, 230, 200, 90, ("TX_IDLE", "READY=1"), GREEN),
                Node("load", 450, 230, 200, 90, ("LOAD", "10 BIT FRAME"), YELLOW),
                Node("shift", 780, 230, 220, 90, ("TX_SHIFT", "SHIFT ON TICK"), YELLOW),
                Node("done", 780, 420, 220, 80, ("DONE", "TX HIGH"), GREEN),
            ],
            [
                Edge("idle", "load", "VALID"),
                Edge("load", "shift", "BUSY"),
                Edge("shift", "shift", "TICK & MORE", bend=(1030, 170)),
                Edge("shift", "done", "LAST BIT"),
                Edge("done", "idle", "NEXT"),
            ],
            ["DISABLE FORCES TX_IDLE", "FRAME IS START DATA STOP", "DATA SHIFTS LSB FIRST"],
        ),
        (
            "uart/docs/images/uart_baud_counter_state.png",
            "UART_BAUD COUNTER",
            [
                Node("reset", 110, 230, 180, 90, ("RESET", "COUNT=0"), BLUE),
                Node("disabled", 400, 230, 210, 90, ("DISABLED", "COUNT=0"), GRAY),
                Node("count", 710, 230, 210, 90, ("COUNT", "INC"), YELLOW),
                Node("tick", 1010, 230, 170, 90, ("TICK", "PULSE"), GREEN),
            ],
            [
                Edge("reset", "disabled", "RST RELEASE"),
                Edge("disabled", "count", "ENABLE"),
                Edge("count", "tick", "TERM"),
                Edge("tick", "count", "NEXT"),
                Edge("count", "disabled", "DISABLE"),
            ],
            ["DIVISOR ZERO MAPS TO ONE", "TICK IS ONE CLOCK CYCLE"],
        ),
        (
            "otp/docs/images/ahb_otp_state.png",
            "AHB_OTP PROGRAM STATE",
            [
                Node("erased", 80, 220, 190, 90, ("ERASED", "ALL 1S"), GREEN),
                Node("locked", 360, 100, 190, 90, ("LOCKED", "NO PROGRAM"), PINK),
                Node("armed", 360, 340, 190, 90, ("ARMED", "KEY OK"), YELLOW),
                Node("prog", 660, 340, 210, 90, ("PROGRAM", "WORD &= WDATA"), YELLOW),
                Node("done", 960, 250, 180, 90, ("DONE", "STATUS"), GREEN),
                Node("err", 660, 100, 210, 90, ("ERROR", "STATUS"), PINK),
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
            ["OPEN RTL PROGRAMS IN ONE RESPONSE CYCLE", "0 TO 1 REQUEST IS REJECTED"],
        ),
        (
            "timer/docs/images/ahb_timer_state.png",
            "AHB_TIMER STATE",
            [
                Node("reset", 80, 230, 190, 90, ("RESET", "CMP=FFFF"), BLUE),
                Node("disabled", 360, 230, 220, 90, ("DISABLED", "MTIME HOLD"), GRAY),
                Node("enabled", 690, 230, 220, 90, ("ENABLED", "MTIME++"), YELLOW),
                Node("pending", 1000, 230, 190, 90, ("PENDING", "IRQ LEVEL"), PINK),
            ],
            [
                Edge("reset", "disabled", "RST RELEASE"),
                Edge("disabled", "enabled", "CTRL.EN"),
                Edge("enabled", "disabled", "CTRL.DIS"),
                Edge("enabled", "pending", "MTIME>=CMP"),
                Edge("pending", "enabled", "CMP FUTURE"),
                Edge("pending", "disabled", "DISABLE"),
            ],
            ["IRQ = PENDING AND IRQ_ENABLE", "SOFTWARE CLEARS BY FUTURE MTIMECMP"],
        ),
        (
            "gpio/docs/images/ahb_gpio_state.png",
            "AHB_GPIO IRQ STATE",
            [
                Node("sync", 90, 210, 210, 90, ("INPUT", "2 STAGE SYNC"), BLUE),
                Node("detect", 390, 210, 220, 90, ("DETECT", "LEVEL EDGE"), YELLOW),
                Node("latched", 700, 210, 220, 90, ("IRQ_STATUS", "LATCHED"), PINK),
                Node("clear", 1010, 210, 180, 90, ("W1C", "CLEAR"), GREEN),
            ],
            [
                Edge("sync", "detect", "SAMPLE"),
                Edge("detect", "latched", "ENABLED HIT"),
                Edge("latched", "clear", "WRITE 1"),
                Edge("clear", "detect", "NEXT"),
            ],
            ["DATA_OUT/DIR ARE NORMAL REGISTERS", "GPIO_IRQ_O IS OR OF ENABLED STATUS"],
        ),
        (
            "intc/docs/images/ahb_intc_state.png",
            "AHB_INTC STATE",
            [
                Node("sync", 80, 230, 190, 90, ("IRQ SYNC", "2 STAGE"), BLUE),
                Node("pend", 350, 230, 210, 90, ("PENDING", "SET BITS"), PINK),
                Node("best", 650, 230, 220, 90, ("BEST SRC", "> THRESH"), YELLOW),
                Node("claim", 960, 150, 190, 90, ("CLAIM", "READ ID"), GREEN),
                Node("comp", 960, 330, 190, 90, ("COMPLETE", "CLEAR ID"), GREEN),
            ],
            [
                Edge("sync", "pend", "HIGH"),
                Edge("pend", "best", "ENABLE"),
                Edge("best", "claim", "READ"),
                Edge("claim", "comp", "WRITE ID"),
                Edge("comp", "pend", "CLEAR"),
            ],
            ["LOWEST ID WINS TIES", "MEIP ASSERTS WHEN BEST SOURCE EXISTS"],
        ),
        (
            "bus/docs/images/ahb_fabric_2m_state.png",
            "AHB_FABRIC_2M STATE",
            [
                Node("reset", 60, 230, 180, 90, ("RESET", "NO SELECT"), BLUE),
                Node("grant", 310, 230, 220, 90, ("ARBITER", "GRANT M0/M1"), YELLOW),
                Node("decode", 620, 230, 210, 90, ("DECODER", "HSEL"), GREEN),
                Node("slave", 920, 120, 220, 90, ("SLAVE RESP", "MAPPED"), GREEN),
                Node("def", 920, 340, 220, 90, ("DEFAULT", "ERROR"), PINK),
            ],
            [
                Edge("reset", "grant", "REQ"),
                Edge("grant", "decode", "ADDR"),
                Edge("decode", "slave", "MAPPED"),
                Edge("decode", "def", "UNMAPPED"),
                Edge("slave", "grant", "RESP", bend=(760, 80)),
                Edge("def", "grant", "RESP", bend=(760, 560)),
            ],
            ["FABRIC STATE IS COMPOSED FROM ARBITER AND DEFAULT SLAVE", "HREADY LOW HOLDS GRANT"],
        ),
        (
            "bus/docs/images/ahb_arbiter_2m_state.png",
            "AHB_ARBITER_2M GRANT STATE",
            [
                Node("reset", 80, 220, 190, 90, ("RESET", "NO GRANT"), BLUE),
                Node("idle", 350, 220, 190, 90, ("IDLE", "NO REQ"), GRAY),
                Node("m0", 650, 120, 190, 90, ("GRANT M0", "CORE"), GREEN),
                Node("m1", 650, 340, 190, 90, ("GRANT M1", "DMA"), GREEN),
                Node("hold", 960, 230, 190, 90, ("HOLD", "HREADY=0"), YELLOW),
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
            ["LAST_GRANT_Q PROVIDES ROUND ROBIN", "RESPONSE ROUTING FOLLOWS HELD GRANT"],
        ),
        (
            "sram/docs/images/ahb_sram_state.png",
            "AHB_SRAM RESPONSE STATE",
            [
                Node("idle", 100, 230, 190, 90, ("IDLE", "NO XFER"), GRAY),
                Node("cap", 390, 230, 220, 90, ("CAPTURE", "ADDR CTRL"), BLUE),
                Node("read", 710, 120, 210, 90, ("READ RESP", "HRDATA"), GREEN),
                Node("write", 710, 340, 210, 90, ("WRITE RESP", "MERGE LANES"), GREEN),
                Node("err", 1010, 230, 170, 90, ("ERROR", "HRESP"), PINK),
            ],
            [
                Edge("idle", "cap", "SELECTED"),
                Edge("cap", "read", "READ OK"),
                Edge("cap", "write", "WRITE OK"),
                Edge("cap", "err", "BAD XFER"),
                Edge("read", "idle", "NEXT"),
                Edge("write", "idle", "NEXT"),
                Edge("err", "idle", "NEXT"),
            ],
            ["ONE CYCLE AHB RESPONSE MODEL", "HREADY IS ALWAYS HIGH"],
        ),
    ]
    for args in diagrams:
        render(*args)
    render_core_pipe_l3()
    render_ahb_dma_l3()


if __name__ == "__main__":
    main()
