---
name: Horizontal fade layout bounds
description: Layout constraints required by the shared one-line horizontal fade wrapper.
---

The shared one-line horizontal fade wrapper must let its text-field child determine its natural height. Its overlay fades can be positioned against that resulting size; the wrapper must not use StackFit.expand or add a separate ClipRect when it may appear inside a modal Column or Stack. For search fields, keep the content inset inside the scrolling child while the fade remains flush with the editable viewport edge; never spend the inset as a pre-fade layout gap. The fade itself is the edge visibility treatment.

**Why:** a tight expansion in an unbounded vertical parent can fail the modal body layout while the sheet header remains visible, and a wrapper clip creates a second boundary instead of letting text run underneath the fade.

**How to apply:** use loose/default Stack sizing with no wrapper clip in HorizontalEdgeFade; let each child text field or scroll viewport own its normal clipping, keep search text padding inside the child, and keep explicit height constraints at callsites only when a field genuinely needs them.