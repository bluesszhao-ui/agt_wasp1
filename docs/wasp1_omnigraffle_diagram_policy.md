# wasp1 OmniGraffle Diagram Policy

This document defines the required drawing policy for wasp1 architecture,
block, design-spec, timing, and state-machine diagrams.

All new or substantially reworked detailed diagrams must use editable
OmniGraffle source files:

```text
<module>/docs/diagrams/<diagram_name>.graffle
```

Optional PNG or PDF exports may be kept under `docs/images/` for Markdown
preview, but the `.graffle` file is the editable source of truth.

## 1. Drawing Rule

Draw diagrams as editable OmniGraffle geometry. Node shapes may be generated
from exact coordinates when this improves repeatability. Wires must remain
ordinary OmniGraffle native line objects with explicit point lists; do not use
automatic connectors or connector arrowheads.

Before drawing, decide the node shape for each design element:

```text
rectangle     module, datapath block, register bank, memory, interface group
square        compact storage/state marker when square geometry is clearer
circle        reset marker, small event marker, state marker
ellipse       FSM state or abstract state value when this reads better
diamond       decision, priority choice, branch condition
```

Place the shapes intentionally before drawing wires. The diagram should show
the design structure first and then the signal/state flow.

## 2. Grid Policy

The OmniGraffle grid must be visible when the drawing is submitted for review.
Use a 5 pt minor grid and prefer 10 pt placement for major structure.

Alignment rules:

```text
rectangles/squares      all sides and corners align to the grid
ellipses/circles        bounding-box corners align to the grid where practical
diamonds                control-box corners align to the grid where practical
horizontal lines        full line and both endpoints align to the grid
vertical lines          full line and both endpoints align to the grid
diagonal lines          endpoints align to the grid
bend points             align to the grid
arrow tips              align to the grid
```

For non-rectangular shapes, do not force curved or angled edges to coincide
with grid lines. The important requirement is that the shape's semantic points
or control-box corners are grid-aligned.

Spacing rules are mandatory:

```text
ordinary line to unrelated shape      at least 2 grid cells, normally 10 pt
ordinary line to unrelated line       no crossing or overlap
shape to unrelated shape              no overlap
label to line                         at least 2 grid cells, normally 10 pt
label to shape                        no overlap
```

The only permitted overlaps are:

```text
line segment endpoint touches the source/destination shape boundary
two line segments of the same route meet at a bend point
V-arrow line pair meets at the arrow tip
V-arrow tip matches the final body-line endpoint
```

## 3. Wire Drawing Method

Use ordinary native `line` objects and piece them together. Do not use automatic
connectors.

For each path:

```text
1. decide the start point and end point
2. decide the horizontal and/or vertical segment lengths
3. draw each straight segment as its own native line object
4. give each line object an explicit point list
5. join segments visually at grid-aligned endpoints
6. add one V-shaped arrow head only where the path finally enters the destination
```

For a bent path, draw the path from separate horizontal and vertical line
segments. Do not place arrowheads at intermediate bends.

## 4. Arrow Head Method

Directed wires must use a V-shaped arrow head made from two short native line
objects. Do not use connector arrowheads or triangle shapes.

Arrow rules:

```text
horizontal-right path   V tip at the final endpoint grid point
vertical-down path      V tip at the final endpoint grid point
other directions        orient the two short lines so the V tip lands on the endpoint
bent path               arrow only at the final entry into the destination
```

The arrow head is two diagonal line objects that share the destination endpoint
as their tip. The tip and both tail points must land on the 5 pt grid.

## 5. Saved-File Audit

Before visual review, run the saved-file coordinate and overlap audit:

```text
python3 docs/tools/audit_graffle_diagram.py <module>/docs/diagrams/<name>.graffle
```

The audit checks the saved OmniGraffle plist for:

```text
single-page canvas
5 pt grid alignment for shape bounds and line points
native LineGraphic objects with explicit two-point lists
no connector arrowheads
no triangle-shape arrowheads
horizontal/vertical non-arrow segments
V arrowhead diagonals marked by -arrow- object names
no shape overlap
no line-to-shape clearance violation inside 10 pt
no unrelated line-line crossing or overlap
V-arrow tip must match a body-line endpoint
```

## 6. Timing-Class Style

The project-wide timing-class visual style still applies:

```text
SEQ  pale green fill, label includes clk=<clock_name> rst=<reset_name>
COMB pale amber/yellow fill
IF   pale blue fill
```

Do not combine timing classes inside one block. If one module contains both
sequential state and combinational logic, draw separate connected `SEQ` and
`COMB` blocks with clear signal flow. Every sequential block must show its
clock and reset.

The fill color identifies timing class. Use labels, nearby notes, or border
styles for conditions such as reset, error, abort, hit, miss, done, and
priority.

## 7. Completion Checklist

A `.graffle` diagram is not complete until all of the following are true:

```text
editable geometry        drawing content is editable OmniGraffle geometry
grid visible             reviewer can see the grid in OmniGraffle
node shapes chosen       rectangles/circles/ellipses/diamonds/etc. are used deliberately
node alignment           shapes satisfy the grid rules for their geometry
wire endpoints           every line endpoint and bend point is on the grid
element spacing          unrelated elements do not overlap and keep 10 pt spacing
line objects             straight segments are native line objects with explicit points
arrowheads complete      directed paths use two-line V arrowheads
timing class visible     SEQ/COMB/IF color policy is followed
clock/reset shown        every SEQ block names clk=<clock> rst=<reset>
coordinate audit         saved .graffle file passes docs/tools/audit_graffle_diagram.py
visual inspection        final OmniGraffle view is checked before review
```

If any checklist item fails, fix the drawing before asking for review or moving
on to the next implementation task.

## 8. Design-Spec Integration

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
