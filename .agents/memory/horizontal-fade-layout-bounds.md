---
name: Horizontal fade layout bounds
description: Layout constraints required by the shared one-line horizontal fade wrapper.
---

The shared one-line horizontal fade wrapper must let its text-field child determine its natural height. Its overlay fades can be positioned against that resulting size; the wrapper must not use StackFit.expand or add a separate ClipRect when it may appear inside a modal Column or Stack. For search fields, the editable viewport spans icon edge to icon edge, while one inner content inset per side defines the usable text area and the fade starts at those inner boundaries; never add a second pre-fade gap or clip.

**Why:** a tight expansion in an unbounded vertical parent can fail the modal body layout while the sheet header remains visible, and a wrapper clip creates a second boundary instead of letting text run underneath the fade.

**How to apply:** use loose/default Stack sizing with no wrapper clip in HorizontalEdgeFade; let each child text field or scroll viewport own its normal clipping, keep search text padding inside the child, position search fades one inset inward from the wrapper edges, and keep explicit height constraints at callsites only when a field genuinely needs them.