#!/usr/bin/env python3
"""Remote-bitbang smoke client for the wasp1 Verilator harness."""

import argparse
import socket
import subprocess
import sys
import time

DMI_ADDR_WIDTH = 7
DMI_DR_WIDTH = DMI_ADDR_WIDTH + 34
DMI_OP_NOP = 0
DMI_OP_READ = 1
DMI_OP_WRITE = 2
DMI_RESP_SUCCESS = 0
DMI_ADDR_DMCONTROL = 0x10
DMI_ADDR_DMSTATUS = 0x11
DMSTATUS_VERSION_AUTH_MASK = 0x0000008F
DMSTATUS_VERSION_AUTH_VALUE = 0x00000082
DMSTATUS_ALL_RUNNING = 0x00000C00
DMSTATUS_ALL_HALTED = 0x00000300
JTAG_IR_DTMCS = 0b10000
JTAG_IR_DMI = 0b10001
JTAG_IDCODE_VALUE = 0x100001CF


class RemoteBitbang:
    def __init__(self, host: str, port: int):
        self.sock = socket.create_connection((host, port), timeout=5.0)

    def close(self) -> None:
        try:
            try:
                self.sock.sendall(b"Q")
            except OSError:
                pass
        finally:
            self.sock.close()

    def write_pins(self, tck: int, tms: int, tdi: int) -> None:
        value = ord("0") | ((1 if tdi else 0) << 0) | ((1 if tms else 0) << 1) | (
            (1 if tck else 0) << 2
        )
        self.sock.sendall(bytes([value]))

    def read_tdo(self) -> int:
        self.sock.sendall(b"R")
        value = self.sock.recv(1)
        if value not in (b"0", b"1"):
            raise RuntimeError(f"bad TDO response: {value!r}")
        return 1 if value == b"1" else 0

    def cycle(self, tms: int, tdi: int) -> int:
        self.write_pins(0, tms, tdi)
        self.write_pins(1, tms, tdi)
        tdo = self.read_tdo()
        self.write_pins(0, tms, tdi)
        return tdo

    def reset_to_idle(self) -> None:
        for _ in range(6):
            self.cycle(1, 0)
        self.cycle(0, 0)

    def set_ir(self, value: int, width: int = 5) -> None:
        self.cycle(1, 0)
        self.cycle(1, 0)
        self.cycle(0, 0)
        self.cycle(0, 0)
        for bit in range(width):
            self.cycle(1 if bit == width - 1 else 0, (value >> bit) & 1)
        self.cycle(1, 0)
        self.cycle(0, 0)

    def scan_dr(self, width: int, data_in: int) -> int:
        data_out = 0
        self.cycle(1, 0)
        self.cycle(0, 0)
        self.cycle(0, 0)
        for bit in range(width):
            tdo = self.cycle(1 if bit == width - 1 else 0, (data_in >> bit) & 1)
            data_out |= tdo << bit
        self.cycle(1, 0)
        self.cycle(0, 0)
        return data_out

    def idle(self, cycles: int) -> None:
        for _ in range(cycles):
            self.cycle(0, 0)


def dmi_packet(op: int, addr: int, data: int) -> int:
    return (op & 0x3) | ((data & 0xFFFFFFFF) << 2) | (
        (addr & ((1 << DMI_ADDR_WIDTH) - 1)) << 34
    )


def dmi_transfer(rbb: RemoteBitbang, op: int, addr: int, data: int) -> tuple[int, int, int]:
    rbb.set_ir(JTAG_IR_DMI)
    rbb.scan_dr(DMI_DR_WIDTH, dmi_packet(op, addr, data))
    rbb.idle(16)
    response = rbb.scan_dr(DMI_DR_WIDTH, dmi_packet(DMI_OP_NOP, 0, 0))
    rsp = response & 0x3
    rsp_data = (response >> 2) & 0xFFFFFFFF
    rsp_addr = (response >> 34) & ((1 << DMI_ADDR_WIDTH) - 1)
    return rsp, rsp_data, rsp_addr


def connect_with_retry(host: str, port: int, timeout_s: float) -> RemoteBitbang:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            return RemoteBitbang(host, port)
        except OSError:
            time.sleep(0.05)
    raise TimeoutError(f"remote-bitbang server did not open {host}:{port}")


def run_smoke(host: str, port: int) -> None:
    rbb = connect_with_retry(host, port, 5.0)
    try:
        rbb.reset_to_idle()
        idcode = rbb.scan_dr(32, 0) & 0xFFFFFFFF
        if idcode != JTAG_IDCODE_VALUE:
            raise AssertionError(f"IDCODE mismatch got=0x{idcode:08x}")

        rbb.set_ir(JTAG_IR_DTMCS)
        dtmcs = rbb.scan_dr(32, 0) & 0xFFFFFFFF
        if (dtmcs & 0xF) != 1:
            raise AssertionError(f"DTMCS version mismatch dtmcs=0x{dtmcs:08x}")
        if ((dtmcs >> 4) & 0x3F) != DMI_ADDR_WIDTH:
            raise AssertionError(f"DTMCS abits mismatch dtmcs=0x{dtmcs:08x}")

        rsp, _, rsp_addr = dmi_transfer(
            rbb, DMI_OP_WRITE, DMI_ADDR_DMCONTROL, 0x00000001
        )
        if rsp != DMI_RESP_SUCCESS or rsp_addr != DMI_ADDR_DMCONTROL:
            raise AssertionError(f"dmcontrol write failed rsp={rsp} addr=0x{rsp_addr:02x}")

        rsp, data, rsp_addr = dmi_transfer(rbb, DMI_OP_READ, DMI_ADDR_DMSTATUS, 0)
        if rsp != DMI_RESP_SUCCESS or rsp_addr != DMI_ADDR_DMSTATUS:
            raise AssertionError(f"dmstatus read failed rsp={rsp} addr=0x{rsp_addr:02x}")
        if (data & DMSTATUS_VERSION_AUTH_MASK) != DMSTATUS_VERSION_AUTH_VALUE:
            raise AssertionError(f"dmstatus identity mismatch data=0x{data:08x}")
        if (data & DMSTATUS_ALL_RUNNING) != DMSTATUS_ALL_RUNNING and (
            data & DMSTATUS_ALL_HALTED
        ) != DMSTATUS_ALL_HALTED:
            raise AssertionError(f"dmstatus data mismatch data=0x{data:08x}")
    finally:
        rbb.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sim", required=True, help="Path to Vwasp1 remote-bitbang binary")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=9824)
    args = parser.parse_args()

    proc = subprocess.Popen(
        [args.sim, f"+rbb-port={args.port}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        run_smoke(args.host, args.port)
        proc.wait(timeout=5.0)
        if proc.returncode != 0:
            output = proc.stdout.read() if proc.stdout else ""
            raise RuntimeError(f"sim exited with {proc.returncode}\n{output}")
    except Exception:
        if proc.poll() is not None and proc.stdout is not None:
            print(proc.stdout.read(), end="")
        raise
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=5.0)

    print("wasp1_rbb_smoke PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
