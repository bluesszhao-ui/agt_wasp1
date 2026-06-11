# ahb_intc Spec

## 1. Purpose

`ahb_intc` provides a PLIC-lite machine external interrupt controller for
wasp1.

## 2. Source Requirements

The controller must accept `IRQ_SRC_COUNT` interrupt source inputs.

Source ID 0 is reserved for `IRQ_ID_NONE` and must never be reported as a
claimable interrupt. Source IDs 1 and above map to the IDs defined in
`wasp1_pkg.sv`.

## 3. Register Requirements

The controller must expose:

```text
PENDING
ENABLE
CLAIM
THRESHOLD
PRIORITY[id]
```

`PENDING` is W1C. `ENABLE` masks sources. `CLAIM` read returns the best
claimable source ID. `CLAIM` write completes a source by clearing its pending
bit. `THRESHOLD` suppresses sources whose priority is not greater than the
threshold.

## 4. Arbitration Requirements

Among enabled pending sources with priority greater than threshold, the
controller must return the highest priority source. If priorities tie, lower
source ID wins.

## 5. Interrupt Output Requirements

`meip_o` must assert when at least one source is enabled, pending, and above
threshold.

## 6. Error Requirements

Only aligned word accesses are supported. Misaligned, non-word, out-of-range,
unknown register, and invalid priority index accesses must return ERROR.

## 7. Verification Requirements

Verification must cover pending capture, W1C clear, enable masking, priority
selection, tie-break, threshold masking, claim/complete, error accesses, and
deterministic random source combinations.
