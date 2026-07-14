"""pyserial-backed Channel B transport for the wasp1 OTP client."""

from __future__ import annotations

import time
from typing import Any

from .protocol import Frame, HEADER, MAGIC, frame_size_from_header


FTDI_VID = 0x0403
FT2232H_PID = 0x6010


class SerialTransport:
    """One-request-at-a-time framed transport with bounded retry behavior."""

    def __init__(
        self,
        port: str,
        *,
        baudrate: int = 115200,
        timeout: float = 2.0,
        retries: int = 2,
    ) -> None:
        try:
            import serial
        except ImportError as exc:
            raise RuntimeError(
                "pyserial is required; install host/requirements.txt"
            ) from exc

        self._timeout = timeout
        self._retries = retries
        self._serial = serial.Serial(
            port=port,
            baudrate=baudrate,
            timeout=min(timeout, 0.1),
            write_timeout=timeout,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
        )

    def close(self) -> None:
        """Close the underlying operating-system serial handle."""
        self._serial.close()

    def __enter__(self) -> "SerialTransport":
        return self

    def __exit__(self, *_args: Any) -> None:
        self.close()

    def _read_exact(self, length: int, deadline: float) -> bytes:
        data = bytearray()
        while len(data) < length and time.monotonic() < deadline:
            chunk = self._serial.read(length - len(data))
            if chunk:
                data.extend(chunk)
        if len(data) != length:
            raise TimeoutError(f"serial receive timed out after {len(data)}/{length} bytes")
        return bytes(data)

    def _read_frame(self) -> Frame:
        deadline = time.monotonic() + self._timeout
        # Search for the two-byte magic so console noise or a partial old frame
        # cannot be mistaken for an OTP response.
        window = bytearray()
        while time.monotonic() < deadline:
            byte = self._serial.read(1)
            if not byte:
                continue
            window.extend(byte)
            if len(window) > len(MAGIC):
                del window[0]
            if bytes(window) == MAGIC:
                break
        else:
            raise TimeoutError("serial receive timed out waiting for frame magic")

        header = MAGIC + self._read_exact(HEADER.size - len(MAGIC), deadline)
        total_size = frame_size_from_header(header)
        tail = self._read_exact(total_size - HEADER.size, deadline)
        return Frame.decode(header + tail)

    def exchange(self, request: Frame) -> Frame:
        """Send a frame and retry the same idempotent sequence on timeout."""
        encoded = request.encode()
        last_error: Exception | None = None
        for _attempt in range(self._retries + 1):
            try:
                self._serial.write(encoded)
                self._serial.flush()
                return self._read_frame()
            except (TimeoutError, OSError) as exc:
                last_error = exc
        assert last_error is not None
        raise last_error


def select_ft2232h_channel_b(ports: Any) -> str:
    """Select Channel B from pyserial-like port records.

    Windows often exposes only Interface B as a COM port after Interface A is
    bound to WinUSB, and its description may omit the channel name. In that
    case the sole FT2232H VCP candidate is unambiguous.
    """
    matches = []
    explicit_channel_b = []
    for port in ports:
        if port.vid != FTDI_VID or port.pid != FT2232H_PID:
            continue
        matches.append(port.device)
        interface = (port.interface or "").lower()
        description = (port.description or "").lower()
        if "interface 1" in interface or "channel b" in description or interface.endswith(" b"):
            explicit_channel_b.append(port.device)

    if len(explicit_channel_b) == 1:
        return explicit_channel_b[0]
    if len(explicit_channel_b) > 1:
        raise RuntimeError(
            "multiple explicit FT2232H Channel B interfaces found; select one "
            "with --port: " + ", ".join(explicit_channel_b)
        )

    if not matches:
        raise RuntimeError("no FT2232H Channel B VCP interface was detected")
    if len(matches) == 1:
        return matches[0]
    raise RuntimeError(
        "multiple ambiguous FT2232H VCP interfaces found; select Channel B "
        "with --port: " + ", ".join(matches)
    )


def auto_detect_port() -> str:
    """Enumerate host serial ports and select the FT2232H Channel B VCP."""
    try:
        from serial.tools import list_ports
    except ImportError as exc:
        raise RuntimeError(
            "pyserial is required; install host/requirements.txt"
        ) from exc
    return select_ft2232h_channel_b(list_ports.comports())
