"""Enumeration-policy tests that do not require pyserial or USB hardware."""

from __future__ import annotations

from dataclasses import dataclass
import unittest

from wasp1_otp.serial_transport import select_ft2232h_channel_b


@dataclass
class Port:
    device: str
    vid: int | None
    pid: int | None
    interface: str | None = None
    description: str | None = None


class PortSelectionTest(unittest.TestCase):
    def test_only_ft2232h_vcp_is_selected_without_channel_text(self) -> None:
        ports = [Port("COM7", 0x0403, 0x6010, description="USB Serial Port")]
        self.assertEqual(select_ft2232h_channel_b(ports), "COM7")

    def test_explicit_channel_b_wins_when_both_interfaces_are_vcp(self) -> None:
        ports = [
            Port("/dev/ttyUSB0", 0x0403, 0x6010, interface="Interface 0"),
            Port("/dev/ttyUSB1", 0x0403, 0x6010, interface="Interface 1"),
        ]
        self.assertEqual(select_ft2232h_channel_b(ports), "/dev/ttyUSB1")

    def test_multiple_ambiguous_ports_require_explicit_selection(self) -> None:
        ports = [
            Port("COM7", 0x0403, 0x6010),
            Port("COM8", 0x0403, 0x6010),
        ]
        with self.assertRaisesRegex(RuntimeError, "ambiguous"):
            select_ft2232h_channel_b(ports)

    def test_unrelated_ftdi_product_is_not_selected(self) -> None:
        ports = [Port("COM9", 0x0403, 0x6001)]
        with self.assertRaisesRegex(RuntimeError, "no FT2232H"):
            select_ft2232h_channel_b(ports)


if __name__ == "__main__":
    unittest.main()
