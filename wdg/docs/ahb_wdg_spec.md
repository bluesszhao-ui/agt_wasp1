# ahb_wdg Spec

## 1. Purpose

`ahb_wdg` provides the SoC watchdog timer peripheral. Software programs a
timeout, enables the watchdog, and periodically writes a fixed kick key before
the counter expires.

## 2. Register Requirements

The watchdog must expose word registers at `WDG_BASE`:

| Offset | Name | Access | Requirement |
| --- | --- | --- | --- |
| `0x00` | `CTRL` | RW | Enable, IRQ enable, reset-request enable, write-one clear. |
| `0x04` | `STATUS` | RO | Expired, reset request, bad key, running status. |
| `0x08` | `TIMEOUT` | RW | 32-bit terminal count. |
| `0x0C` | `COUNT` | RO | Current watchdog count. |
| `0x10` | `KICK` | WO | Writing `WDG_KICK_VALUE` feeds the watchdog. |

## 3. Behavior Requirements

When `CTRL.enable` is set and the watchdog is not expired, `COUNT` increments
once per `hclk_i` cycle. Expiry occurs when the next count value reaches
`TIMEOUT`; `TIMEOUT=0` means immediate expiry after enable.

On expiry:

```text
STATUS.expired      <- 1
STATUS.reset_req    <- CTRL.reset_en
wdg_irq_o           = STATUS.expired && CTRL.irq_en
wdg_reset_req_o     = STATUS.reset_req
```

Writing the correct `KICK` key clears `COUNT`, `expired`, and `reset_req`.
Writing any other value to `KICK` must not feed the watchdog and must latch
`STATUS.keyerr`.

Writing `CTRL.clear=1` clears `COUNT`, `expired`, `reset_req`, and `keyerr`.

## 4. Error Requirements

Only aligned word register accesses are supported. Misaligned, non-word,
out-of-range, and unknown register accesses must return AHB ERROR.

## 5. Verification Requirements

Verification must cover reset values, register read/write paths, timeout IRQ,
timeout reset request, valid kick, bad kick key, clear behavior, IRQ masking,
AHB error paths, deterministic random timeout values, and target macro lint.
