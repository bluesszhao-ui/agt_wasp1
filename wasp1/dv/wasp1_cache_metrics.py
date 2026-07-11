#!/usr/bin/env python3
"""Run wasp1 OTP firmware images and summarize cache/runtime metrics."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
import re
import subprocess
import sys


PROGRAMS = [
    {
        "label": "hello_uart",
        "hex": "../llvm_s1/build/smoke/hello_uart_otp.hex",
        "plusargs": [],
    },
    {
        "label": "long_boot",
        "hex": "../llvm_s1/build/smoke/long_boot_otp.hex",
        "plusargs": ["+WASP1_LONG_BOOT_CHECK"],
    },
    {
        "label": "mixed_irq_dma",
        "hex": "../llvm_s1/build/smoke/mixed_irq_dma_otp.hex",
        "plusargs": ["+WASP1_MIXED_IRQ_DMA_CHECK"],
    },
    {
        "label": "system_stress",
        "hex": "../llvm_s1/build/smoke/system_stress_otp.hex",
        "plusargs": ["+WASP1_SYSTEM_STRESS_CHECK"],
    },
    {
        "label": "random_irq_stress",
        "hex": "../llvm_s1/build/smoke/random_irq_stress_otp.hex",
        "plusargs": [
            "+WASP1_RANDOM_IRQ_STRESS_CHECK",
            "+WASP1_RANDOM_IRQ_SEED=1a2b3c4d",
        ],
    },
    {
        "label": "dma_copy",
        "hex": "../llvm_s1/build/smoke/dma_copy_otp.hex",
        "plusargs": ["+WASP1_DMA_COPY_CHECK"],
    },
    {
        "label": "dma_irq",
        "hex": "../llvm_s1/build/smoke/dma_irq_otp.hex",
        "plusargs": ["+WASP1_DMA_IRQ_CHECK"],
    },
    {
        "label": "gpio_irq",
        "hex": "../llvm_s1/build/smoke/gpio_irq_otp.hex",
        "plusargs": ["+WASP1_GPIO_IRQ_CHECK"],
    },
    {
        "label": "uart_irq",
        "hex": "../llvm_s1/build/smoke/uart_irq_otp.hex",
        "plusargs": ["+WASP1_UART_IRQ_CHECK"],
    },
    {
        "label": "uart_rx_irq",
        "hex": "../llvm_s1/build/smoke/uart_rx_irq_otp.hex",
        "plusargs": ["+WASP1_UART_RX_IRQ_CHECK"],
    },
    {
        "label": "timer_irq",
        "hex": "../llvm_s1/build/smoke/timer_irq_otp.hex",
        "plusargs": ["+WASP1_TIMER_IRQ_CHECK"],
    },
    {
        "label": "otp_program",
        "hex": "../llvm_s1/build/smoke/otp_program_otp.hex",
        "plusargs": ["+WASP1_OTP_PROGRAM_CHECK"],
    },
]

METRIC_RE = re.compile(r"^WASP1_METRICS\s+(?P<body>.*)$", re.MULTILINE)


def parse_metric_line(text: str) -> dict[str, str]:
    match = METRIC_RE.search(text)
    if not match:
        raise AssertionError("simulation log did not contain WASP1_METRICS")
    fields: dict[str, str] = {}
    for item in match.group("body").split():
        key, value = item.split("=", 1)
        fields[key] = value
    return fields


def milli_to_percent(value: str) -> str:
    milli = int(value)
    return f"{milli / 10.0:.1f}"


def milli_to_decimal(value: str) -> str:
    milli = int(value)
    return f"{milli / 1000.0:.3f}"


def run_program(sim: Path, program: dict[str, object], logs_dir: Path) -> dict[str, str]:
    label = str(program["label"])
    hex_path = str(program["hex"])
    plusargs = [str(arg) for arg in program["plusargs"]]
    log_path = logs_dir / f"cache_metrics_{label}.log"
    cmd = [
        str(sim),
        f"+WASP1_OTP_HEX={hex_path}",
        "+WASP1_METRICS",
        f"+WASP1_METRICS_LABEL={label}",
        *plusargs,
    ]
    result = subprocess.run(cmd, text=True, capture_output=True, check=False)
    log_path.write_text(result.stdout + result.stderr, encoding="utf-8")
    if result.returncode != 0:
        raise AssertionError(f"{label}: simulation failed, see {log_path}")
    metrics = parse_metric_line(result.stdout + result.stderr)
    if metrics.get("label") != label:
        raise AssertionError(f"{label}: metric label mismatch {metrics.get('label')!r}")
    return metrics


def write_csv(rows: list[dict[str, str]], csv_path: Path) -> None:
    fieldnames = [
        "label",
        "cycles",
        "retired",
        "ipc",
        "cpi",
        "ic_req",
        "ic_hit",
        "ic_miss",
        "ic_hit_pct",
        "dc_req",
        "dc_cacheable",
        "dc_uncached",
        "dc_hit",
        "dc_miss",
        "dc_hit_pct",
        "dc_load",
        "dc_store",
        "dc_refill",
        "dc_store_hit",
        "rf_commits",
    ]
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})


def write_markdown(rows: list[dict[str, str]], md_path: Path) -> None:
    lines = [
        "# wasp1 Cache Metrics",
        "",
        "| Program | Cycles | Retired | IPC | CPI | I-hit % | D-hit % | I req/hit/miss | D req/cache/uncached/hit/miss |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
    ]
    for row in rows:
        lines.append(
            "| {label} | {cycles} | {retired} | {ipc} | {cpi} | {ic_hit_pct} | "
            "{dc_hit_pct} | {ic_req}/{ic_hit}/{ic_miss} | "
            "{dc_req}/{dc_cacheable}/{dc_uncached}/{dc_hit}/{dc_miss} |".format(**row)
        )
    lines.append("")
    md_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sim", required=True, type=Path)
    parser.add_argument("--logs-dir", default="logs", type=Path)
    parser.add_argument("--csv", default="logs/cache_metrics.csv", type=Path)
    parser.add_argument("--markdown", default="logs/cache_metrics.md", type=Path)
    parser.add_argument("--program", action="append", default=[])
    args = parser.parse_args()

    args.logs_dir.mkdir(parents=True, exist_ok=True)
    selected = set(args.program)
    programs = [prog for prog in PROGRAMS if not selected or prog["label"] in selected]
    if not programs:
        raise SystemExit("no programs selected")

    rows: list[dict[str, str]] = []
    for program in programs:
        metrics = run_program(args.sim, program, args.logs_dir)
        row = dict(metrics)
        row["ipc"] = milli_to_decimal(row["ipc_milli"])
        row["cpi"] = milli_to_decimal(row["cpi_milli"])
        row["ic_hit_pct"] = milli_to_percent(row["ic_hit_milli"])
        row["dc_hit_pct"] = milli_to_percent(row["dc_hit_milli"])
        rows.append(row)

    write_csv(rows, args.csv)
    write_markdown(rows, args.markdown)
    print(f"WASP1_CACHE_METRICS wrote {args.csv} and {args.markdown}")
    for row in rows:
        print(
            "WASP1_CACHE_METRICS_ROW "
            f"label={row['label']} cycles={row['cycles']} retired={row['retired']} "
            f"ipc={row['ipc']} cpi={row['cpi']} "
            f"ic_hit_pct={row['ic_hit_pct']} dc_hit_pct={row['dc_hit_pct']}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
