"""Safety-oriented high-level wasp1 OTP programming client."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol
import struct

from .protocol import Command, Frame, FrameKind, MAX_PAYLOAD, Status, VERSION


CAP_READ = 1 << 0
CAP_PROGRAM = 1 << 1
CAP_LOCK = 1 << 2
HELLO_PAYLOAD = struct.Struct("<IIHH")
STATUS_PAYLOAD = struct.Struct("<I")
READ_LENGTH = struct.Struct("<H")


class OtpError(RuntimeError):
    """Base error for a rejected or failed OTP operation."""


class OtpProtocolError(OtpError):
    """Raised when the target response does not match its request."""


class Transport(Protocol):
    """Minimal exchange interface shared by serial and test transports."""

    def exchange(self, request: Frame) -> Frame:
        """Send one request and return its matching response."""


@dataclass(frozen=True)
class DeviceInfo:
    """Capabilities and geometry reported by the target loader."""

    otp_data_size: int
    capabilities: int
    max_payload: int
    loader_version: int


class OtpClient:
    """Chunked OTP operations with sequence and irreversible-bit checks."""

    def __init__(self, transport: Transport) -> None:
        self._transport = transport
        self._next_sequence = 0
        self._device_info: DeviceInfo | None = None

    def _request(
        self,
        command: Command,
        *,
        address: int = 0,
        payload: bytes = b"",
        flags: int = 0,
    ) -> Frame:
        sequence = self._next_sequence
        self._next_sequence = (self._next_sequence + 1) & 0xFFFF
        request = Frame(
            kind=FrameKind.REQUEST,
            sequence=sequence,
            command=command,
            address=address,
            flags=flags,
            payload=payload,
        )
        response = self._transport.exchange(request)

        if response.kind != FrameKind.RESPONSE:
            raise OtpProtocolError("target returned a request instead of a response")
        if response.version != VERSION:
            raise OtpProtocolError(
                f"target protocol version {response.version} is unsupported"
            )
        if response.sequence != sequence:
            raise OtpProtocolError(
                f"response sequence {response.sequence} does not match {sequence}"
            )
        if response.command != command:
            raise OtpProtocolError("response command does not match its request")
        if response.status != Status.OK:
            raise OtpError(
                f"target rejected {command.name}: {response.status.name} "
                f"at 0x{address:08x}"
            )
        return response

    def probe(self) -> DeviceInfo:
        """Read and cache loader capabilities and OTP geometry."""
        response = self._request(Command.HELLO)
        if len(response.payload) != HELLO_PAYLOAD.size:
            raise OtpProtocolError("HELLO response has an invalid payload length")
        otp_data_size, capabilities, max_payload, loader_version = (
            HELLO_PAYLOAD.unpack(response.payload)
        )
        if max_payload == 0 or max_payload > MAX_PAYLOAD:
            raise OtpProtocolError("target reported an invalid maximum payload")
        self._device_info = DeviceInfo(
            otp_data_size=otp_data_size,
            capabilities=capabilities,
            max_payload=max_payload,
            loader_version=loader_version,
        )
        return self._device_info

    def _info(self) -> DeviceInfo:
        return self._device_info if self._device_info is not None else self.probe()

    def _check_range(self, offset: int, length: int) -> DeviceInfo:
        info = self._info()
        if offset < 0 or length < 0 or offset + length > info.otp_data_size:
            raise OtpError(
                f"range 0x{offset:x}..0x{offset + length:x} exceeds "
                f"OTP data size 0x{info.otp_data_size:x}"
            )
        return info

    def read(self, offset: int, length: int) -> bytes:
        """Read an arbitrary byte range in bounded response chunks."""
        info = self._check_range(offset, length)
        if not info.capabilities & CAP_READ:
            raise OtpError("target loader does not advertise read capability")

        result = bytearray()
        while len(result) < length:
            chunk_length = min(info.max_payload, length - len(result))
            chunk_offset = offset + len(result)
            response = self._request(
                Command.READ,
                address=chunk_offset,
                payload=READ_LENGTH.pack(chunk_length),
            )
            if len(response.payload) != chunk_length:
                raise OtpProtocolError(
                    f"READ returned {len(response.payload)} bytes, "
                    f"expected {chunk_length}"
                )
            result.extend(response.payload)
        return bytes(result)

    def status(self) -> int:
        """Return target OTP status bits using the hardware register encoding."""
        response = self._request(Command.STATUS)
        if len(response.payload) != STATUS_PAYLOAD.size:
            raise OtpProtocolError("STATUS response has an invalid payload length")
        return STATUS_PAYLOAD.unpack(response.payload)[0]

    def program(self, offset: int, data: bytes, *, verify: bool = True) -> None:
        """Precheck, program, and optionally verify a word-aligned image."""
        info = self._check_range(offset, len(data))
        if not info.capabilities & CAP_PROGRAM:
            raise OtpError("target loader does not advertise program capability")
        if offset & 0x3 or len(data) & 0x3:
            raise OtpError("OTP program offset and image length must be word aligned")

        current = self.read(offset, len(data))
        for index, (old_byte, new_byte) in enumerate(zip(current, data)):
            if new_byte & ~old_byte:
                raise OtpError(
                    f"illegal 0 -> 1 request at OTP offset "
                    f"0x{offset + index:08x}: current=0x{old_byte:02x}, "
                    f"requested=0x{new_byte:02x}"
                )

        chunk_limit = info.max_payload & ~0x3
        if chunk_limit == 0:
            raise OtpProtocolError("target payload limit cannot hold one OTP word")
        for chunk_start in range(0, len(data), chunk_limit):
            chunk = data[chunk_start : chunk_start + chunk_limit]
            self._request(
                Command.PROGRAM,
                address=offset + chunk_start,
                payload=chunk,
            )

        if verify:
            self.verify(offset, data)

    def verify(self, offset: int, expected: bytes) -> None:
        """Compare target bytes with an image and report the first mismatch."""
        observed = self.read(offset, len(expected))
        if observed == expected:
            return
        mismatch = next(
            index
            for index, pair in enumerate(zip(observed, expected))
            if pair[0] != pair[1]
        )
        raise OtpError(
            f"verify mismatch at OTP offset 0x{offset + mismatch:08x}: "
            f"observed=0x{observed[mismatch]:02x}, "
            f"expected=0x{expected[mismatch]:02x}"
        )

    def lock(self) -> None:
        """Permanently lock target OTP programming after capability checking."""
        info = self._info()
        if not info.capabilities & CAP_LOCK:
            raise OtpError("target loader does not advertise lock capability")
        self._request(Command.LOCK)
