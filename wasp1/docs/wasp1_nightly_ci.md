# wasp1 Nightly Verification

## 1. Purpose

The nightly job extends the fast four-seed integration baseline without making
ordinary development builds wait for a long campaign. It exercises the same
generated RV32I/Zicsr OTP firmware and independent SystemVerilog scoreboard
over 32 cold boots and 384 non-overlapping pseudo-random interrupt rounds.

## 2. Local Entry Point

```text
make -C wasp1 sim-random-irq-nightly
```

The default root seed is `0xc001d00d` and the default run count is 32. They may
be overridden with `RANDOM_IRQ_NIGHTLY_BASE_SEED` and
`RANDOM_IRQ_NIGHTLY_SEED_COUNT`. Seed zero is always rejected.

The target first runs the campaign-driver unit tests, rebuilds the generated
OTP firmware and full SoC simulator, then launches one independent simulation
per seed. A failed simulator, missing PASS record, captured-seed mismatch,
mailbox/scoreboard error, duplicate seed, overlapping generated schedule, or
missing aggregate selector class fails the target.

## 3. CI Entry Point

`.github/workflows/wasp1-nightly.yml` runs daily at 18:17 UTC and also supports
manual dispatch. Changes on `main` to the workflow, campaign driver/tests,
top-level testbench, Makefile entry point, or random-IRQ firmware also trigger
the job; unrelated commits do not. It installs LLVM, the separate `lld`
linker package, and Verilator on a hosted macOS runner, selects Python 3.13 for
the campaign tooling, requires complete RISC-V toolchain support, invokes the
local target, and archives reports for 30 days even when the campaign fails.

## 4. Outputs

```text
wasp1/logs/random_irq_nightly.log
wasp1/logs/random_irq_nightly_summary.json
wasp1/logs/random_irq_nightly_summary.md
wasp1/logs/random_irq_seed_<seed>.log
wasp1/logs/random_irq_runner_test.log
wasp1/logs/tb_wasp1_random_irq_nightly_build.log
```

The JSON and Markdown summaries include run/round/event totals, timer/DMA/GPIO
counts, selector 0/1/2/3 counts, and each seed's final state and packed trace.
Generated reports remain ignored locally; CI preserves them as run artifacts.

## 5. Current Baseline

The first 32-seed run passed 384 distinct rounds and 478 interrupt events:

```text
timer events:       183
DMA events:         197
GPIO events:         98
selector 0/1/2/3: 89/103/98/94
```

This campaign complements directed peripheral, interrupt, DMA, debug, and
module-level tests. It does not replace them.
