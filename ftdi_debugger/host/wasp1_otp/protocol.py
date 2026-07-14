"""Binary framing primitives for the wasp1 UART OTP protocol.

All multi-byte fields are little-endian. CRC32 covers the fixed header and
payload, allowing the target to reject truncated or corrupted UART traffic
before an irreversible OTP operation is started.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import struct
import zlib


MAGIC = b"W1"
VERSION = 1
MAX_PAYLOAD = 256
HEADER = struct.Struct("<2sBBHBBIHH")
CRC = struct.Struct("<I")


class ProtocolError(ValueError):
    """Raised when a byte sequence violates the wire-format contract."""


class FrameKind(IntEnum):
    """Direction encoded in every frame."""

    REQUEST = 0
    RESPONSE = 1


class Command(IntEnum):
    """Commands implemented by the target-side OTP loader."""

    HELLO = 0x01
    READ = 0x10
    PROGRAM = 0x11
    STATUS = 0x20
    LOCK = 0x21


class Status(IntEnum):
    """Target response status values."""

    OK = 0x00
    BAD_COMMAND = 0x01
    BAD_VERSION = 0x02
    BAD_LENGTH = 0x03
    BAD_ADDRESS = 0x04
    BAD_ALIGNMENT = 0x05
    CRC_ERROR = 0x06
    LOCKED = 0x07
    ILLEGAL_TRANSITION = 0x08
    PROGRAM_ERROR = 0x09
    BUSY = 0x0A
    INTERNAL_ERROR = 0x0B


@dataclass(frozen=True)
class Frame:
    """One request or response frame on the Channel B UART link."""

    kind: FrameKind
    sequence: int
    command: Command
    status: Status = Status.OK
    address: int = 0
    flags: int = 0
    payload: bytes = b""
    version: int = VERSION

    def encode(self) -> bytes:
        """Serialize the frame and append its little-endian CRC32."""
        if not 0 <= self.sequence <= 0xFFFF:
            raise ProtocolError("sequence is outside the 16-bit range")
        if not 0 <= self.address <= 0xFFFFFFFF:
            raise ProtocolError("address is outside the 32-bit range")
        if not 0 <= self.flags <= 0xFFFF:
            raise ProtocolError("flags are outside the 16-bit range")
        if len(self.payload) > MAX_PAYLOAD:
            raise ProtocolError(f"payload exceeds {MAX_PAYLOAD} bytes")

        header = HEADER.pack(
            MAGIC,
            self.version,
            int(self.kind),
            self.sequence,
            int(self.command),
            int(self.status),
            self.address,
            len(self.payload),
            self.flags,
        )
        body = header + self.payload
        return body + CRC.pack(zlib.crc32(body) & 0xFFFFFFFF)

    @classmethod
    def decode(cls, data: bytes) -> "Frame":
        """Validate and deserialize exactly one complete frame."""
        if len(data) < HEADER.size + CRC.size:
            raise ProtocolError("frame length is shorter than the fixed overhead")

        (magic, version, kind, sequence, command, status, address,
         payload_length, flags) = HEADER.unpack_from(data)
        if magic != MAGIC:
            raise ProtocolError("frame magic does not match")
        if payload_length > MAX_PAYLOAD:
            raise ProtocolError("declared payload exceeds protocol maximum")

        expected_length = HEADER.size + payload_length + CRC.size
        if len(data) != expected_length:
            raise ProtocolError(
                f"frame length is {len(data)}, expected {expected_length}"
            )

        expected_crc = CRC.unpack_from(data, HEADER.size + payload_length)[0]
        actual_crc = zlib.crc32(data[: HEADER.size + payload_length]) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise ProtocolError("frame CRC32 does not match")

        try:
            frame_kind = FrameKind(kind)
            frame_command = Command(command)
            frame_status = Status(status)
        except ValueError as exc:
            raise ProtocolError(f"unknown frame enum value: {exc}") from exc

        return cls(
            kind=frame_kind,
            sequence=sequence,
            command=frame_command,
            status=frame_status,
            address=address,
            flags=flags,
            payload=data[HEADER.size : HEADER.size + payload_length],
            version=version,
        )


def frame_size_from_header(header: bytes) -> int:
    """Return total encoded size after validating a fixed-size header."""
    if len(header) != HEADER.size:
        raise ProtocolError("incomplete frame header")
    fields = HEADER.unpack(header)
    if fields[0] != MAGIC:
        raise ProtocolError("frame magic does not match")
    payload_length = fields[7]
    if payload_length > MAX_PAYLOAD:
        raise ProtocolError("declared payload exceeds protocol maximum")
    return HEADER.size + payload_length + CRC.size
