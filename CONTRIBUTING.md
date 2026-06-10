# Contributing to wasp1

## Workflow

wasp1 is developed module by module. Do not skip directly to top-level SoC
integration unless the lower-level module dependencies are already verified.

For each hardware module:

```text
1. Update design spec
2. Update verification plan
3. Implement RTL
4. Add filelists and Makefile targets
5. Add self-checking tests
6. Run lint and simulation
7. Update verification report
8. Commit the verified milestone
```

## Verification Expectations

Smoke tests are not enough.

Each module should cover:

```text
normal behavior
boundary cases
inactive or idle behavior
error responses
stall or backpressure behavior when applicable
random or deterministic-random stimulus when useful
self-checking scoreboard or reference model when practical
coverage summary in the verification report
```

Every verification report must include a time-sequenced action table.

## RTL Style

Use synthesizable SystemVerilog.

Preferred style:

```text
logic
always_ff
always_comb
interface-based structured connections
package-based shared constants and types
one module per .sv file
explicit reset behavior
```

Do not place unsynthesizable test-only code under `rtl/`.

## Commands

Before submitting changes, run the relevant module checks and the current root
lint flow:

```sh
make lint
```

For bus decoder work:

```sh
make -C bus sim
```

## Commit Policy

Prefer one verified module milestone per commit.

A good commit usually includes:

```text
design/doc updates
RTL
testbench
filelist/Makefile changes
verification report
```

Avoid tiny follow-up commits for missing documentation or missing coverage when
they can be included in the same verified milestone.

## Generated Files

Do not commit generated build, log, or waveform outputs unless explicitly
requested for archival purposes.
