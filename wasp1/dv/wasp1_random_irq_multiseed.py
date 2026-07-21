#!/usr/bin/env python3
"""Run and summarize reproducible multi-seed IRQ firmware campaigns."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess


ROUNDS_PER_SEED = 12
PASS_RE = re.compile(
    r"Random IRQ stress: seed=(?P<seed>0x[0-9a-fA-F]+) "
    r"state=(?P<state>0x[0-9a-fA-F]+) "
    r"trace=(?P<trace>0x[0-9a-fA-F]+) events=(?P<events>[0-9]+) "
    r"timer=(?P<timer>[0-9]+) dma=(?P<dma>[0-9]+) "
    r"gpio=(?P<gpio>[0-9]+) event_sum=(?P<event_sum>0x[0-9a-fA-F]+) "
    r"data_sum=(?P<data_sum>0x[0-9a-fA-F]+) PASS"
)


def parse_seed(text: str) -> int:
    """Accept compact hexadecimal seeds while rejecting zero-lock xorshift."""
    try:
        value = int(text, 16)
    except ValueError as error:
        raise argparse.ArgumentTypeError("seed must be hexadecimal") from error
    if value <= 0 or value > 0xFFFFFFFF:
        raise argparse.ArgumentTypeError("seed must be a nonzero 32-bit hex value")
    return value


def parse_positive_count(text: str) -> int:
    """Parse a strictly positive campaign run count."""
    value = int(text, 10)
    if value <= 0:
        raise argparse.ArgumentTypeError("campaign count must be positive")
    return value


def xorshift32(value: int) -> int:
    """Match the firmware PRNG with explicit 32-bit truncation."""
    value ^= (value << 13) & 0xFFFFFFFF
    value ^= value >> 17
    value ^= (value << 5) & 0xFFFFFFFF
    return value & 0xFFFFFFFF


def generate_seed_campaign(generator_seed: int, count: int) -> list[int]:
    """Generate stable seeds whose 12-round PRNG windows do not overlap."""
    seeds: list[int] = []
    state = generator_seed
    for _ in range(count):
        state = xorshift32(state)
        if state == 0 or state in seeds:
            raise ValueError("campaign generator produced a zero or duplicate seed")
        seeds.append(state)
        # Firmware advances once per round. Skip that complete window before
        # choosing the next seed so aggregate coverage counts distinct states.
        for _ in range(ROUNDS_PER_SEED):
            state = xorshift32(state)
    return seeds


def selector_histogram(trace: int, rounds: int = ROUNDS_PER_SEED) -> list[int]:
    """Decode the packed two-bit operation selectors reported by firmware."""
    counts = [0, 0, 0, 0]
    for round_index in range(rounds):
        counts[(trace >> (round_index * 2)) & 0x3] += 1
    return counts


def parse_pass_output(output: str, expected_seed: int) -> dict[str, object]:
    """Parse one self-checking simulation result and validate seed capture."""
    match = PASS_RE.search(output)
    if match is None:
        raise ValueError("simulation PASS record is missing")

    captured_seed = int(match.group("seed"), 16)
    if captured_seed != expected_seed:
        raise ValueError(
            f"seed capture mismatch: expected 0x{expected_seed:08x}, "
            f"observed 0x{captured_seed:08x}"
        )

    trace = int(match.group("trace"), 16)
    record: dict[str, object] = {
        "seed": f"0x{captured_seed:08x}",
        "state": f"0x{int(match.group('state'), 16):08x}",
        "trace": f"0x{trace:08x}",
        "events": int(match.group("events")),
        "timer": int(match.group("timer")),
        "dma": int(match.group("dma")),
        "gpio": int(match.group("gpio")),
        "event_sum": f"0x{int(match.group('event_sum'), 16):08x}",
        "data_sum": f"0x{int(match.group('data_sum'), 16):08x}",
        "selectors": selector_histogram(trace),
    }
    if record["events"] != record["timer"] + record["dma"] + record["gpio"]:
        raise ValueError("reported event total does not equal per-source totals")
    return record


def build_summary(
    records: list[dict[str, object]],
    mode: str,
    generator_seed: int | None,
) -> dict[str, object]:
    """Aggregate source and selector coverage across independent runs."""
    selector_totals = [0, 0, 0, 0]
    for record in records:
        selectors = record["selectors"]
        assert isinstance(selectors, list)
        selector_totals = [
            total + int(count)
            for total, count in zip(selector_totals, selectors, strict=True)
        ]

    summary: dict[str, object] = {
        "result": "PASS",
        "mode": mode,
        "seed_count": len(records),
        "rounds_per_seed": ROUNDS_PER_SEED,
        "total_rounds": len(records) * ROUNDS_PER_SEED,
        "total_events": sum(int(record["events"]) for record in records),
        "timer_events": sum(int(record["timer"]) for record in records),
        "dma_events": sum(int(record["dma"]) for record in records),
        "gpio_events": sum(int(record["gpio"]) for record in records),
        "selector_counts": selector_totals,
        "records": records,
    }
    if generator_seed is not None:
        summary["generator_seed"] = f"0x{generator_seed:08x}"
    return summary


def require_complete_selector_coverage(summary: dict[str, object]) -> None:
    """Fail a long campaign that never schedules one operation class."""
    counts = summary["selector_counts"]
    assert isinstance(counts, list)
    if len(counts) != 4 or any(int(count) == 0 for count in counts):
        raise ValueError(f"incomplete selector coverage: {counts}")
    if sum(int(count) for count in counts) != int(summary["total_rounds"]):
        raise ValueError("selector total does not equal campaign round total")


def write_summary_json(path: Path, summary: dict[str, object]) -> None:
    """Write a deterministic machine-readable campaign report."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_summary_markdown(path: Path, summary: dict[str, object]) -> None:
    """Write a review-friendly report with aggregate and per-seed results."""
    selectors = summary["selector_counts"]
    assert isinstance(selectors, list)
    lines = [
        "# wasp1 Random IRQ Campaign Summary",
        "",
        "| Metric | Result |",
        "| --- | ---: |",
        f"| Seeds | {summary['seed_count']} |",
        f"| Rounds | {summary['total_rounds']} |",
        f"| Interrupt events | {summary['total_events']} |",
        f"| Timer events | {summary['timer_events']} |",
        f"| DMA events | {summary['dma_events']} |",
        f"| GPIO events | {summary['gpio_events']} |",
        f"| Selector 0/1/2/3 | {'/'.join(str(value) for value in selectors)} |",
        "",
        "| Seed | Final state | Trace | Events | Timer | DMA | GPIO | Selectors 0/1/2/3 |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    records = summary["records"]
    assert isinstance(records, list)
    for record in records:
        assert isinstance(record, dict)
        selector_text = "/".join(str(value) for value in record["selectors"])
        lines.append(
            f"| {record['seed']} | {record['state']} | {record['trace']} | "
            f"{record['events']} | {record['timer']} | {record['dma']} | "
            f"{record['gpio']} | {selector_text} |"
        )
    lines.extend(["", "Result: **PASS**", ""])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sim", required=True, type=Path)
    parser.add_argument("--otp-hex", required=True, type=Path)
    parser.add_argument("--logs-dir", default="logs", type=Path)
    seed_group = parser.add_mutually_exclusive_group(required=True)
    seed_group.add_argument("--seeds", nargs="+", type=parse_seed)
    seed_group.add_argument("--generate-count", type=parse_positive_count)
    parser.add_argument("--generator-seed", default=0xC001D00D, type=parse_seed)
    parser.add_argument("--require-selector-coverage", action="store_true")
    parser.add_argument("--summary-json", type=Path)
    parser.add_argument("--summary-markdown", type=Path)
    args = parser.parse_args()

    if args.seeds is not None:
        seeds = args.seeds
        mode = "explicit"
        generator_seed = None
    else:
        seeds = generate_seed_campaign(args.generator_seed, args.generate_count)
        mode = "generated"
        generator_seed = args.generator_seed
    if len(set(seeds)) != len(seeds):
        raise SystemExit("campaign contains duplicate seeds")

    args.logs_dir.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    for seed in seeds:
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
        if result.returncode != 0:
            raise SystemExit(f"seed=0x{seed_text} FAIL; see {log_path}")
        try:
            record = parse_pass_output(output, seed)
        except ValueError as error:
            raise SystemExit(f"seed=0x{seed_text} FAIL: {error}; see {log_path}") from error
        records.append(record)
        print(
            f"WASP1_RANDOM_IRQ_SEED seed={record['seed']} "
            f"state={record['state']} trace={record['trace']} "
            f"events={record['events']} timer={record['timer']} "
            f"dma={record['dma']} gpio={record['gpio']} PASS"
        )

    summary = build_summary(records, mode, generator_seed)
    if args.require_selector_coverage:
        try:
            require_complete_selector_coverage(summary)
        except ValueError as error:
            raise SystemExit(f"campaign FAIL: {error}") from error
    if args.summary_json is not None:
        write_summary_json(args.summary_json, summary)
    if args.summary_markdown is not None:
        write_summary_markdown(args.summary_markdown, summary)

    selectors = summary["selector_counts"]
    assert isinstance(selectors, list)
    print(
        f"WASP1_RANDOM_IRQ_CAMPAIGN seeds={summary['seed_count']} "
        f"rounds={summary['total_rounds']} events={summary['total_events']} "
        f"timer={summary['timer_events']} dma={summary['dma_events']} "
        f"gpio={summary['gpio_events']} "
        f"selectors={'/'.join(str(value) for value in selectors)} PASS"
    )
    print(f"WASP1_RANDOM_IRQ_MULTI_SEED seeds={len(seeds)} PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
