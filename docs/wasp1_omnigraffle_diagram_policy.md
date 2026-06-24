# wasp1 OmniGraffle Diagram Policy

This document defines the preferred diagram workflow for new or substantially
reworked wasp1 design-spec figures.

The project previously generated many state and block diagrams as PNG files.
Those checked-in PNG files remain valid historical documentation. Going
forward, editable OmniGraffle source files should be the primary diagram
artifact whenever a figure is detailed enough to benefit from visual editing.

## 1. Artifact Policy

Preferred source location:

```text
<module>/docs/diagrams/<block_or_view_name>.graffle
```

Optional preview exports may be kept under:

```text
<module>/docs/images/<block_or_view_name>.png
<module>/docs/images/<block_or_view_name>.pdf
```

The `.graffle` file is the editable source of truth. A PNG or PDF export is a
review convenience for Markdown readers and should not replace the text
transition tables in the design spec.

## 2. Stable Drawing Method

Use OmniGraffle native objects, but avoid automatic connectors.

Required drawing rules:

```text
flow/block boxes     native rectangle shapes
straight wires       native line objects with explicit point lists
bent wires           split into separate horizontal and vertical line objects
arrow heads          two short diagonal line segments forming a V shape
grid                 5 pt minor grid, 10 pt preferred major alignment
object names         stable user names for generated/repeated objects
audit                coordinate audit before accepting the figure
```

Do not use:

```text
automatic connectors
shape-bound connector arrows
solid triangle arrowheads
direct low-level edits to complex .graffle file internals
large unbacked-up batch edits to an existing drawing
```

## 3. Timing-Class Style

The project-wide timing-class visual style still applies:

```text
SEQ  pale green fill, label includes clk=<clock_name> rst=<reset_name>
COMB pale amber/yellow fill
IF   pale blue fill
```

Do not combine timing classes in one block. If a module has both sequential
state and combinational control, draw separate `SEQ` and `COMB` blocks with
explicit signal flow between them.

The main fill color is reserved for timing class only. Use border style, nearby
notes, or action labels for reset, error, abort, hit, miss, done, and priority
semantics.

## 4. Grid and Geometry Rules

Use a visible 5 pt grid and place all important coordinates on grid points:

```text
rectangle left/right/top/bottom edges
line segment endpoints
orthogonal bend points
arrowhead tips and tail endpoints
semantic dots or branch points
```

Major structure should land on 10 pt coordinates where practical. For bent
wires, draw each orthogonal segment as an independent line object instead of a
single automatic connector.

## 5. Arrow Rules

Draw arrowheads as V-shaped chevrons made from two short line segments.

Recommended conventions:

```text
right arrow tip: line to tip_x - 10, tip_y - 5
                 line to tip_x - 10, tip_y + 5

down arrow tip:  line to tip_x - 5, tip_y - 10
                 line to tip_x + 5, tip_y - 10
```

Place arrowheads where a logical flow enters the destination block. Do not put
arrowheads at every bend. Avoid endpoint dots under arrow tips because they
hide the chevron.

## 6. Scripted Editing Rules

When AppleScript is used to edit OmniGraffle:

```text
1. copy a known-good .graffle file before experimental edits
2. confirm the front document name before modifying it
3. keep handler definitions outside the tell application block
4. delete only objects with known user names before regenerating them
5. save after each stable drawing step
6. run a coordinate audit after generation
7. perform a final visual inspection in OmniGraffle
```

Suggested generated object names:

```text
grid-line
grid-dot
grid-arrow-line
wasp1-seq-block
wasp1-comb-block
wasp1-if-block
```

## 7. Design-Spec Integration

Every design spec that references an OmniGraffle diagram should list:

```text
editable source: docs/diagrams/<name>.graffle
preview export:  docs/images/<name>.png or docs/images/<name>.pdf, if present
detail level:    L1, L2, or L3
clock domains:   every clock/reset used by SEQ blocks
```

The Markdown design spec must still include text describing reset behavior,
transition conditions, update priority, and key side effects. The editable
figure improves visual review; the text remains the diff-friendly engineering
contract.
