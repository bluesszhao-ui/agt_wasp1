"""Behavioral tests for chunking, safety checks, and response validation."""

from __future__ import annotations

import struct
import unittest

from wasp1_otp.client import (
    CAP_LOCK,
    CAP_PROGRAM,
    CAP_READ,
    HELLO_PAYLOAD,
    OtpClient,
    OtpError,
    OtpProtocolError,
    READ_LENGTH,
    STATUS_PAYLOAD,
)
from wasp1_otp.protocol import Command, Frame, FrameKind, Status


class ModelTransport:
    """In-memory target model enforcing the same monotonic OTP semantics."""

    def __init__(self, size: int = 1024, max_payload: int = 16) -> None:
        self.memory = bytearray([0xFF] * size)
        self.max_payload = max_payload
        self.locked = False
        self.requests: list[Frame] = []
        self.response_sequence_delta = 0

    def response(self, request: Frame, *, status: Status = Status.OK, payload: bytes = b"") -> Frame:
        return Frame(
            kind=FrameKind.RESPONSE,
            sequence=(request.sequence + self.response_sequence_delta) & 0xFFFF,
            command=request.command,
            status=status,
            address=request.address,
            payload=payload,
        )

    def exchange(self, request: Frame) -> Frame:
        self.requests.append(request)
        if request.command == Command.HELLO:
            return self.response(
                request,
                payload=HELLO_PAYLOAD.pack(
                    len(self.memory),
                    CAP_READ | CAP_PROGRAM | CAP_LOCK,
                    self.max_payload,
                    1,
                ),
            )
        if request.command == Command.READ:
            length = READ_LENGTH.unpack(request.payload)[0]
            end = request.address + length
            if end > len(self.memory):
                return self.response(request, status=Status.BAD_ADDRESS)
            return self.response(request, payload=bytes(self.memory[request.address:end]))
        if request.command == Command.PROGRAM:
            if self.locked:
                return self.response(request, status=Status.LOCKED)
            end = request.address + len(request.payload)
            if end > len(self.memory):
                return self.response(request, status=Status.BAD_ADDRESS)
            current = self.memory[request.address:end]
            if any(new & ~old for old, new in zip(current, request.payload)):
                return self.response(request, status=Status.ILLEGAL_TRANSITION)
            self.memory[request.address:end] = bytes(
                old & new for old, new in zip(current, request.payload)
            )
            return self.response(request)
        if request.command == Command.STATUS:
            return self.response(
                request,
                payload=STATUS_PAYLOAD.pack(0x8 if self.locked else 0),
            )
        if request.command == Command.LOCK:
            self.locked = True
            return self.response(request)
        return self.response(request, status=Status.BAD_COMMAND)


class ClientTest(unittest.TestCase):
    def test_probe_reports_geometry_and_capabilities(self) -> None:
        client = OtpClient(ModelTransport(size=0xFF00, max_payload=64))
        info = client.probe()
        self.assertEqual(info.otp_data_size, 0xFF00)
        self.assertEqual(info.max_payload, 64)
        self.assertEqual(info.capabilities, CAP_READ | CAP_PROGRAM | CAP_LOCK)

    def test_read_is_chunked_at_target_limit(self) -> None:
        transport = ModelTransport(max_payload=8)
        transport.memory[:20] = bytes(range(20))
        client = OtpClient(transport)
        self.assertEqual(client.read(0, 20), bytes(range(20)))
        read_requests = [r for r in transport.requests if r.command == Command.READ]
        self.assertEqual([READ_LENGTH.unpack(r.payload)[0] for r in read_requests], [8, 8, 4])

    def test_program_prechecks_chunks_and_verifies(self) -> None:
        transport = ModelTransport(max_payload=8)
        client = OtpClient(transport)
        image = bytes.fromhex("1234567890abcdef00112233")
        client.program(4, image)
        self.assertEqual(transport.memory[4:16], image)
        program_requests = [r for r in transport.requests if r.command == Command.PROGRAM]
        self.assertEqual([len(r.payload) for r in program_requests], [8, 4])

    def test_illegal_zero_to_one_is_rejected_before_program_command(self) -> None:
        transport = ModelTransport()
        transport.memory[0:4] = bytes.fromhex("00ffffff")
        client = OtpClient(transport)
        with self.assertRaisesRegex(OtpError, "illegal 0 -> 1"):
            client.program(0, bytes.fromhex("01ffffff"))
        self.assertFalse(any(r.command == Command.PROGRAM for r in transport.requests))

    def test_unaligned_program_is_rejected(self) -> None:
        client = OtpClient(ModelTransport())
        with self.assertRaisesRegex(OtpError, "word aligned"):
            client.program(2, b"\xff\xff\xff\xff")
        with self.assertRaisesRegex(OtpError, "word aligned"):
            client.program(0, b"\xff")

    def test_out_of_range_read_is_rejected_locally(self) -> None:
        transport = ModelTransport(size=32)
        client = OtpClient(transport)
        with self.assertRaisesRegex(OtpError, "exceeds"):
            client.read(28, 8)
        self.assertFalse(any(r.command == Command.READ for r in transport.requests))

    def test_target_error_is_reported_with_context(self) -> None:
        transport = ModelTransport()
        transport.locked = True
        client = OtpClient(transport)
        with self.assertRaisesRegex(OtpError, "LOCKED"):
            client.program(0, b"\x00\x00\x00\x00", verify=False)

    def test_sequence_mismatch_is_rejected(self) -> None:
        transport = ModelTransport()
        transport.response_sequence_delta = 1
        with self.assertRaisesRegex(OtpProtocolError, "sequence"):
            OtpClient(transport).probe()

    def test_lock_and_status_follow_hardware_lock_bit(self) -> None:
        client = OtpClient(ModelTransport())
        self.assertEqual(client.status(), 0)
        client.lock()
        self.assertEqual(client.status(), 0x8)


if __name__ == "__main__":
    unittest.main()
