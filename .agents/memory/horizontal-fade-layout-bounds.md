---
name: Horizontal fade layout bounds
description: Layout constraints required by the shared one-line horizontal fade wrapper.
---

The shared one-line horizontal fade wrapper must let its text-field child determine its natural height. Its overlay fades can be positioned against that resulting size; the wrapper must not use StackFit.expand when it may appear inside a modal Column or Stack.

**Why:** a tight expansion in an unbounded vertical parent can fail the modal body layout while the sheet header remains visible.

**How to apply:** use loose/default Stack sizing in HorizontalEdgeFade and keep explicit height constraints at callsites only when a field genuinely needs them.