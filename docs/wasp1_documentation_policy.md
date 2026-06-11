# wasp1 Documentation Policy

## 1. Required Documents

Each implemented first-level module must provide:

```text
<module>/docs/<module_or_block>_spec.md
<module>/docs/<module_or_block>_design_spec.md
<module>/docs/<module>_verification_plan.md
<module>/docs/<module>_verification_report.md
```

Important submodules must also provide separate `spec` and `design_spec`
documents when they have a meaningful standalone contract.

## 2. Spec vs Design Spec

`spec` is the requirement and contract document.

It defines:

```text
required behavior
external interface
software-visible register map
protocol requirements
reset behavior
error behavior
interrupt behavior
IC/FPGA target requirements
verification requirements
out-of-scope behavior
```

It should not depend on the chosen implementation.

`design_spec` is the implementation document.

It defines:

```text
internal blocks
FSMs
datapaths
register organization
storage structure
timing implementation
implementation-specific block diagrams
target-macro implementation choices
design rationale
```

## 3. Naming

Use explicit filenames:

```text
ahb_uart_spec.md
ahb_uart_design_spec.md
uart_tx_spec.md
uart_tx_design_spec.md
```

Do not use one document to silently serve both purposes.

## 4. Block Diagrams

Design specs must contain non-mermaid block diagrams using plain text or
checked-in image assets.

Spec documents may include high-level interface diagrams when useful, but the
required detailed wiring/block diagram belongs in the design spec.

## 5. Update Rule

When RTL, registers, interface behavior, target support, or verification scope
changes, update both:

```text
the affected spec
the affected design spec
```

Verification plans and reports must remain aligned with the spec requirements.
