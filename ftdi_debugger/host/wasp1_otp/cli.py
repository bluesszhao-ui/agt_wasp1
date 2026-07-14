"""Command-line interface for safe wasp1 OTP inspection and programming."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

from .client import CAP_LOCK, CAP_PROGRAM, CAP_READ, OtpClient, OtpError
from .serial_transport import SerialTransport, auto_detect_port


def integer(text: str) -> int:
    """Parse decimal or conventional 0x/0o/0b command-line integers."""
    return int(text, 0)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="wasp1-otp",
        description="Program wasp1 OTP through FT2232H Channel B UART",
    )
    parser.add_argument("--port", help="serial device; auto-detected when omitted")
    parser.add_argument("--baud", type=integer, default=115200)
    parser.add_argument("--timeout", type=float, default=2.0)
    parser.add_argument("--retries", type=int, default=2)
    commands = parser.add_subparsers(dest="operation", required=True)

    commands.add_parser("probe", help="show loader and OTP capabilities")
    commands.add_parser("status", help="show raw OTP hardware status")

    read = commands.add_parser("read", help="read OTP bytes into a file")
    read.add_argument("--offset", required=True, type=integer)
    read.add_argument("--length", required=True, type=integer)
    read.add_argument("--output", required=True, type=Path)

    program = commands.add_parser("program", help="irreversibly program an image")
    program.add_argument("image", type=Path)
    program.add_argument("--offset", required=True, type=integer)
    program.add_argument("--no-verify", action="store_true")
    program.add_argument(
        "--yes-program",
        action="store_true",
        help="required acknowledgement that OTP programming is irreversible",
    )

    verify = commands.add_parser("verify", help="compare OTP with an image")
    verify.add_argument("image", type=Path)
    verify.add_argument("--offset", required=True, type=integer)

    lock = commands.add_parser("lock", help="permanently disable OTP programming")
    lock.add_argument(
        "--yes-lock",
        action="store_true",
        help="required acknowledgement that the lock operation is permanent",
    )
    return parser


def capability_text(mask: int) -> str:
    names = []
    for bit, name in ((CAP_READ, "read"), (CAP_PROGRAM, "program"), (CAP_LOCK, "lock")):
        if mask & bit:
            names.append(name)
    return ",".join(names) if names else "none"


def run(args: argparse.Namespace) -> None:
    port = args.port or auto_detect_port()
    with SerialTransport(
        port,
        baudrate=args.baud,
        timeout=args.timeout,
        retries=args.retries,
    ) as transport:
        client = OtpClient(transport)
        if args.operation == "probe":
            info = client.probe()
            print(f"port: {port}")
            print(f"loader protocol: {info.loader_version}")
            print(f"OTP data size: 0x{info.otp_data_size:x} ({info.otp_data_size} bytes)")
            print(f"maximum payload: {info.max_payload} bytes")
            print(f"capabilities: {capability_text(info.capabilities)}")
        elif args.operation == "status":
            print(f"OTP status: 0x{client.status():08x}")
        elif args.operation == "read":
            data = client.read(args.offset, args.length)
            args.output.write_bytes(data)
            print(f"read {len(data)} bytes to {args.output}")
        elif args.operation == "program":
            if not args.yes_program:
                raise OtpError("program requires --yes-program")
            data = args.image.read_bytes()
            client.program(args.offset, data, verify=not args.no_verify)
            suffix = " without verification" if args.no_verify else " and verified"
            print(f"programmed {len(data)} bytes at 0x{args.offset:x}{suffix}")
        elif args.operation == "verify":
            data = args.image.read_bytes()
            client.verify(args.offset, data)
            print(f"verified {len(data)} bytes at 0x{args.offset:x}")
        elif args.operation == "lock":
            if not args.yes_lock:
                raise OtpError("lock requires --yes-lock")
            client.lock()
            print("OTP programming is permanently locked")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        run(args)
    except (OtpError, RuntimeError, OSError, ValueError) as exc:
        print(f"wasp1-otp: error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
