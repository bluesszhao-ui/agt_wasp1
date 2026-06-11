# ahb_gpio Spec

## 1. Purpose

`ahb_gpio` provides a 32-bit software-controlled GPIO peripheral and interrupt
source.

## 2. Register Requirements

The GPIO block must expose:

```text
DATA_IN
DATA_OUT
DIR
SET
CLR
TOGGLE
IRQ_EN
IRQ_TYPE
IRQ_POL
IRQ_STATUS
```

## 3. IO Requirements

External inputs must be synchronized before software reads them or interrupt
logic observes them.

`DIR` bit value `1` means output enabled for that bit.

`SET`, `CLR`, and `TOGGLE` must update output bits without requiring a software
read-modify-write sequence.

## 4. Interrupt Requirements

Each bit must support:

```text
level high
level low
rising edge
falling edge
```

Only enabled interrupt bits may set `IRQ_STATUS`. `IRQ_STATUS` must be W1C.

## 5. Error Requirements

Only aligned word register accesses are supported. Misaligned, non-word,
out-of-range, and unknown register accesses must return ERROR.

## 6. Verification Requirements

Verification must cover input sync, output controls, direction, level and edge
interrupts, masking, W1C clear, register errors, and deterministic random output
checks.
