# ahb_timer Spec

## 1. Purpose

`ahb_timer` provides the machine timer peripheral and timer interrupt source.

## 2. Register Requirements

The timer must expose:

```text
CTRL
STATUS
MTIME_LO
MTIME_HI
CMP_LO
CMP_HI
```

`mtime` and `mtimecmp` are 64-bit software-visible values accessed as 32-bit
halves.

## 3. Behavior Requirements

When enabled, `mtime` must increment once per `hclk_i` cycle.

Pending condition:

```text
mtime >= mtimecmp
```

Interrupt condition:

```text
pending && irq_enable
```

`mtimecmp` must reset to all ones so reset does not immediately assert pending.

## 4. Error Requirements

Only aligned word register accesses are supported. Misaligned, non-word,
out-of-range, and unknown register accesses must return ERROR.

## 5. Verification Requirements

Verification must cover reset, counter enable/disable, compare pending, IRQ
masking, pending clear by future compare, register errors, and deterministic
random compare cases.
