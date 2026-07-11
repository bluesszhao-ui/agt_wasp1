#!/usr/bin/env python3
"""Run the deterministic IRQ firmware across a reproducible seed campaign."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess


PASS_RE = re.compile(
    r"Random IRQ stress: seed=(?P<seed>0x[0-9a-f]+) "
    r"state=(?P<state>0x[0-9a-f]+) "
    r"trace=(?P<trace>0x[0-9a-f]+) events=(?P<events>[0-9]+) "
    r"timer=(?P<timer>[0-9]+) dma=(?P<dma>[0-9]+) "
    r"gpio=(?P<gpio>[0-9]+).* PASS"
)


def parse_seed(text: str) -> int:
    """Accept compact hexadecimal seeds while rejecting zero-lock xorshift."""
    value = int(text, 16)
    if value <= 0 or value > 0xFFFFFFFF:
        raise argparse.ArgumentTypeError("seed must be a nonzero 32-bit hex value")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sim", required=True, type=Path)
    parser.add_argument("--otp-hex", required=True, type=Path)
    parser.add_argument("--logs-dir", default="logs", type=Path)
    parser.add_argument("--seeds", nargs="+", required=True, type=parse_seed)
    args = parser.parse_args()

    args.logs_dir.mkdir(parents=True, exist_ok=True)
    for seed in args.seeds:
        seed_text = f"{seed:08x}"
        log_path = args.logs_dir / f"random_irq_seed_{seed_text}.log"
        command = [
            str(args.sim),
            f"+WASP1_OTP_HEX={args.otp_hex}",
            "+WASP1_RANDOM_IRQ_STRESS_CHECK",
            f"+WASP1_RANDOM_IRQ_SEED={seed_text}",
        ]
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        output = result.stdout + result.stderr
        log_path.write_text(output, encoding="utf-8")
        match = PASS_RE.search(output)
        if result.returncode != 0 or match is None:
            raise SystemExit(f"seed=0x{seed_text} FAIL; see {log_path}")
        if match.group("seed") != f"0x{seed_text}":
            raise SystemExit(f"seed=0x{seed_text} capture mismatch; see {log_path}")
        print(
            f"WASP1_RANDOM_IRQ_SEED seed=0x{seed_text} "
            f"state={match.group('state')} trace={match.group('trace')} "
            f"events={match.group('events')} timer={match.group('timer')} "
            f"dma={match.group('dma')} gpio={match.group('gpio')} PASS"
        )

    print(f"WASP1_RANDOM_IRQ_MULTI_SEED seeds={len(args.seeds)} PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
