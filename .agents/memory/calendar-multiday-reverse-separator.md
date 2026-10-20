---
name: Multi-Day separator reverse morph
description: Calendar Day View Single↔Multi separator ownership during the reverse transition.
---

On an explicit Multi Day→Single Day switch while already in Day View, retain the outgoing Multi-Day timeline until its separator animation reaches its dismissed state. Its left hour-label divider must reverse with the Day Banner divider before the Single-Day timeline takes over. Keep this behavior scoped to the direct Single↔Multi switch; List and Month↔Day transitions should not gain this delay.

**Why:** The Day Banner preserves its state and reverses its separator, but an immediate timeline-branch swap disposes the Multi-Day timeline before its line can animate out.

**How to apply:** Reverse the timeline's existing 320ms ease-in-out separator controller, retain the same timeline element during that interval, and release it only when the controller finishes. Preserve the settled Single-Day timeline and avoid retaining Multi-Day chrome during unrelated transitions.
