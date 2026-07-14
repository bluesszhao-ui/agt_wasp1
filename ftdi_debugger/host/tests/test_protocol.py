"""Unit tests for byte-exact OTP wire framing and corruption detection."""

from __future__ import annotations

import unittest

from wasp1_otp.protocol import (
    Command,
    Frame,
    FrameKind,
    HEADER,
    MAX_PAYLOAD,
    ProtocolError,
    Status,
    frame_size_from_header,
)


class FrameTest(unittest.TestCase):
    def test_request_round_trip_preserves_every_field(self) -> None:
        frame = Frame(
            kind=FrameKind.REQUEST,
            sequence=0x1234,
            command=Command.PROGRAM,
            address=0x00001020,
            flags=0x55AA,
            payload=bytes(range(32)),
        )
        self.assertEqual(Frame.decode(frame.encode()), frame)

    def test_hello_request_matches_cross_language_wire_vector(self) -> None:
        frame = Frame(FrameKind.REQUEST, 1, Command.HELLO)
        self.assertEqual(
            frame.encode().hex(),
            "573101000100010000000000000000005ac72f45",
        )

    def test_response_round_trip_preserves_error_status(self) -> None:
        frame = Frame(
            kind=FrameKind.RESPONSE,
            sequence=7,
            command=Command.PROGRAM,
            status=Status.ILLEGAL_TRANSITION,
            address=0x40,
        )
        self.assertEqual(Frame.decode(frame.encode()), frame)

    def test_crc_corruption_is_rejected(self) -> None:
        encoded = bytearray(
            Frame(FrameKind.REQUEST, 1, Command.HELLO).encode()
        )
        encoded[HEADER.size - 1] ^= 0x01
        with self.assertRaisesRegex(ProtocolError, "CRC32"):
            Frame.decode(bytes(encoded))

    def test_truncated_frame_is_rejected(self) -> None:
        encoded = Frame(FrameKind.REQUEST, 1, Command.HELLO).encode()
        with self.assertRaisesRegex(ProtocolError, "length"):
            Frame.decode(encoded[:-1])

    def test_oversized_payload_is_rejected(self) -> None:
        frame = Frame(
            FrameKind.REQUEST,
            1,
            Command.PROGRAM,
            payload=bytes(MAX_PAYLOAD + 1),
        )
        with self.assertRaisesRegex(ProtocolError, "payload exceeds"):
            frame.encode()

    def test_header_reports_complete_frame_size(self) -> None:
        encoded = Frame(
            FrameKind.REQUEST,
            9,
            Command.PROGRAM,
            payload=b"abcd",
        ).encode()
        self.assertEqual(frame_size_from_header(encoded[: HEADER.size]), len(encoded))


if __name__ == "__main__":
    unittest.main()
