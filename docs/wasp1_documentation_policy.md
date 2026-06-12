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

## 5. Sequential State Diagrams

Every implemented sequential module must document its state behavior in the
design spec.

For modules with an explicit FSM, the design spec must include a plain-text
state diagram that shows:

```text
reset state
all named states
transition conditions
key outputs or side effects in each state
error, flush, interrupt, or abort priority where applicable
```

For sequential modules without an explicit FSM, the design spec must include a
plain-text register-transfer, counter-state, FIFO-pointer, or pipeline-state
diagram that shows:

```text
reset values
clock-edge update conditions
hold conditions
clear/flush conditions
priority between simultaneous events
externally visible effects
```

Pure combinational modules do not need a state diagram, but their design spec
should explicitly say they have no sequential state when that matters for
integration.

## 6. Update Rule

When RTL, registers, interface behavior, target support, or verification scope
changes, update both:

```text
the affected spec
the affected design spec
```

Verification plans and reports must remain aligned with the spec requirements.

## 7. Source Commenting

RTL and verification source files are part of the design documentation.

Every implemented `.sv` file must include:

```text
top-of-file module/testbench purpose comment
port comments for RTL modules
comments for meaningful internal signals and registers
comments before major combinational or sequential logic blocks
comments explaining priority, masking, error, trap, interrupt, and protocol behavior
comments for testbench reference models, tasks, and coverage counters
```

Comments should explain design intent and verification purpose. They should not
repeat syntax that is already obvious from the code.
