#!/usr/bin/env python3
"""Run the wasp1 Verilator, OpenOCD, and GDB debug smoke as one regression."""

import argparse
import os
import socket
import subprocess
import sys
import time
from pathlib import Path


def wait_for_port(host: str, port: int, timeout_s: float, name: str) -> None:
    """Wait until a TCP server accepts connections on the requested port."""
    deadline = time.time() + timeout_s
    last_error: OSError | None = None
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=0.5):
                return
        except OSError as exc:
            last_error = exc
            time.sleep(0.05)
    raise TimeoutError(f"{name} did not open {host}:{port}: {last_error}")


def wait_for_log_text(
    log_path: Path,
    text: str,
    timeout_s: float,
    name: str,
    proc: subprocess.Popen[str],
) -> None:
    """Wait until a child tool writes a required marker to its log."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if log_path.exists():
            log_text = log_path.read_text(encoding="utf-8", errors="replace")
            if text in log_text:
                return
        if proc.poll() is not None:
            tail = ""
            if log_path.exists():
                tail = log_path.read_text(encoding="utf-8", errors="replace")[-2000:]
            raise RuntimeError(f"{name} exited before marker {text!r}\n{tail}")
        time.sleep(0.05)
    tail = ""
    if log_path.exists():
        tail = log_path.read_text(encoding="utf-8", errors="replace")[-2000:]
    raise TimeoutError(f"{name} did not emit marker {text!r}\n{tail}")


def terminate_process(proc: subprocess.Popen[str], timeout_s: float = 5.0) -> str:
    """Terminate a child process and return any collected combined output."""
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=timeout_s)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=timeout_s)
    if proc.stdout is None:
        return ""
    return proc.stdout.read()


def run_checked(cmd: list[str], cwd: Path, log_path: Path) -> subprocess.CompletedProcess[str]:
    """Run a foreground tool, tee its output to a log file, and require success."""
    completed = subprocess.run(
        cmd,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    log_path.write_text(completed.stdout, encoding="utf-8")
    if completed.returncode != 0:
        raise RuntimeError(
            f"{cmd[0]} exited with {completed.returncode}; see {log_path}\n"
            f"{completed.stdout}"
        )
    return completed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sim", required=True, help="Path to Vwasp1 remote-bitbang binary")
    parser.add_argument("--openocd-cfg", required=True, help="OpenOCD remote-bitbang cfg")
    parser.add_argument("--gdb-script", required=True, help="GDB command script")
    parser.add_argument("--otp-hex", default="", help="Optional OTP image for GDB stepi")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--rbb-port", type=int, default=9824)
    parser.add_argument("--gdb-port", type=int, default=3333)
    parser.add_argument("--openocd", default="openocd")
    parser.add_argument("--gdb", default="riscv64-elf-gdb")
    parser.add_argument("--logs-dir", default="logs")
    args = parser.parse_args()

    repo_module_dir = Path.cwd()
    logs_dir = Path(args.logs_dir)
    logs_dir.mkdir(parents=True, exist_ok=True)

    sim_cmd = [args.sim, f"+rbb-port={args.rbb_port}", "+rbb-keepalive"]
    if args.otp_hex:
        sim_cmd.append(f"+WASP1_OTP_HEX={args.otp_hex}")

    sim_log = logs_dir / "sim_openocd_gdb_sim.log"
    openocd_log = logs_dir / "sim_openocd_gdb_openocd.log"
    gdb_log = logs_dir / "sim_openocd_gdb_gdb.log"

    with sim_log.open("w", encoding="utf-8") as sim_out:
        sim_proc = subprocess.Popen(
            sim_cmd,
            cwd=repo_module_dir,
            stdout=sim_out,
            stderr=subprocess.STDOUT,
            text=True,
        )

    openocd_proc: subprocess.Popen[str] | None = None
    try:
        wait_for_port(args.host, args.rbb_port, 10.0, "remote-bitbang simulator")

        with openocd_log.open("w", encoding="utf-8") as openocd_out:
            openocd_proc = subprocess.Popen(
                [
                    args.openocd,
                    "-c",
                    "telnet_port disabled",
                    "-c",
                    "tcl_port disabled",
                    "-c",
                    f"gdb_port {args.gdb_port}",
                    "-c",
                    f"set RBB_PORT {args.rbb_port}",
                    "-f",
                    args.openocd_cfg,
                ],
                cwd=repo_module_dir,
                stdout=openocd_out,
                stderr=subprocess.STDOUT,
                text=True,
            )

        wait_for_log_text(
            openocd_log,
            f"Listening on port {args.gdb_port} for gdb connections",
            15.0,
            "OpenOCD",
            openocd_proc,
        )

        run_checked(
            [
                args.gdb,
                "-q",
                "-batch",
                "-ex",
                f"set remotetimeout 10",
                "-x",
                args.gdb_script,
            ],
            repo_module_dir,
            gdb_log,
        )

        openocd_text = openocd_log.read_text(encoding="utf-8", errors="replace")
        gdb_text = gdb_log.read_text(encoding="utf-8", errors="replace")
        if "hart 0: XLEN=32" not in openocd_text:
            raise AssertionError("OpenOCD did not report hart 0 XLEN=32")
        if "Error:" in openocd_text:
            raise AssertionError("OpenOCD reported an error")
        if "Error in sourced command file" in gdb_text or "remote failure" in gdb_text:
            raise AssertionError("GDB reported a command or remote failure")
        if "Inferior 1" not in gdb_text and "detached" not in gdb_text.lower():
            raise AssertionError("GDB did not detach cleanly")
    finally:
        if openocd_proc is not None:
            terminate_process(openocd_proc)
        terminate_process(sim_proc)

    print("wasp1_openocd_gdb_smoke PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
