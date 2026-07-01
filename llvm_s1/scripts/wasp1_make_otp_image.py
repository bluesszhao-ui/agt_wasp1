#!/usr/bin/env python3
"""Create wasp1 OTP initialization images from ELF or raw binary input.

The primary output is a 32-bit word-oriented hex file for SystemVerilog
``$readmemh`` into ``logic [31:0]`` memories. Input bytes are interpreted as the
processor-visible little-endian byte stream, so bytes ``01 02 03 04`` become the
hex word ``04030201`` at word address 0.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path


DEFAULT_OTP_BYTES = 0x0000FF00
DEFAULT_ERASED_BYTE = 0xFF


def parse_int(text: str) -> int:
    """Parse decimal or 0x-prefixed integer command-line values."""
    return int(text, 0)


def detect_format(path: Path, requested: str) -> str:
    """Resolve auto format detection using the ELF magic number."""
    if requested != "auto":
        return requested
    with path.open("rb") as handle:
        magic = handle.read(4)
    return "elf" if magic == b"\x7fELF" else "bin"


def elf_to_binary(path: Path, objcopy: str) -> bytes:
    """Convert an ELF file to a flat binary by using llvm-objcopy."""
    with tempfile.TemporaryDirectory(prefix="wasp1_otp_") as tmpdir:
        out_path = Path(tmpdir) / "image.bin"
        cmd = [objcopy, "-O", "binary", str(path), str(out_path)]
        try:
            subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except FileNotFoundError as exc:
            raise RuntimeError(f"objcopy tool not found: {objcopy}") from exc
        except subprocess.CalledProcessError as exc:
            stderr = exc.stderr.decode("utf-8", errors="replace").strip()
            raise RuntimeError(f"objcopy failed: {stderr}") from exc
        return out_path.read_bytes()


def load_payload(path: Path, image_format: str, objcopy: str) -> bytes:
    """Load raw payload bytes from an ELF or binary input file."""
    if image_format == "bin":
        return path.read_bytes()
    if image_format == "elf":
        return elf_to_binary(path, objcopy)
    raise ValueError(f"unsupported input format {image_format}")


def build_image(payload: bytes, image_size: int, fill_byte: int) -> bytes:
    """Pad payload to the exact OTP executable data-window size."""
    if image_size <= 0:
        raise ValueError("image size must be positive")
    if not 0 <= fill_byte <= 0xFF:
        raise ValueError("fill byte must be in range 0..255")
    if len(payload) > image_size:
        raise ValueError(f"payload is {len(payload)} bytes, larger than OTP image size {image_size}")
    return payload + bytes([fill_byte]) * (image_size - len(payload))


def write_hex_words(image: bytes, out_path: Path) -> None:
    """Write one little-endian 32-bit memory word per line."""
    if len(image) % 4 != 0:
        raise ValueError("OTP image size must be a multiple of four bytes")
    with out_path.open("w", encoding="ascii") as handle:
        for offset in range(0, len(image), 4):
            word = int.from_bytes(image[offset : offset + 4], byteorder="little")
            handle.write(f"{word:08x}\n")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Build wasp1 OTP initialization images")
    parser.add_argument("--input", required=True, type=Path, help="Input ELF or raw binary file")
    parser.add_argument("--format", choices=("auto", "elf", "bin"), default="auto", help="Input format")
    parser.add_argument("--output-hex", required=True, type=Path, help="Output readmemh hex path")
    parser.add_argument("--output-bin", type=Path, help="Optional padded binary output path")
    parser.add_argument("--size", type=parse_int, default=DEFAULT_OTP_BYTES, help="OTP data-window bytes")
    parser.add_argument("--fill", type=parse_int, default=DEFAULT_ERASED_BYTE, help="Erased fill byte")
    parser.add_argument("--objcopy", default=os.environ.get("WASP1_OBJCOPY", "llvm-objcopy"))
    args = parser.parse_args(argv)

    try:
        image_format = detect_format(args.input, args.format)
        payload = load_payload(args.input, image_format, args.objcopy)
        image = build_image(payload, args.size, args.fill)
        args.output_hex.parent.mkdir(parents=True, exist_ok=True)
        write_hex_words(image, args.output_hex)
        if args.output_bin is not None:
            args.output_bin.parent.mkdir(parents=True, exist_ok=True)
            args.output_bin.write_bytes(image)
    except Exception as exc:  # pragma: no cover - exercised through shell tests.
        print(f"FAIL {exc}", file=sys.stderr)
        return 1

    print(
        f"PASS otp image format={image_format} payload_bytes={len(payload)} "
        f"image_bytes={len(image)} hex={args.output_hex}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
