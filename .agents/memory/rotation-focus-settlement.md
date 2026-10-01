---
name: Rotation endpoint focus settlement
description: Preserve active text focus when an orientation change arrives as a single endpoint metric and the IME blurs late.
---

When the first orientation metrics event is already within tolerance of the new endpoint, start and finalize the rotation from that event; the platform may send no second metrics callback. Keep the pre-rotation focus target through one short post-settle IME window and retry once if focus is still absent. Carry that target across a second rotation if no new field has taken focus, but do not steal focus from a different live field.

**Why:** Some platform/window combinations deliver portrait-to-landscape as one size update and may send the keyboard blur after that update. If endpoint cleanup depends on a later metrics event, saved focus is never restored; if the focus snapshot is consumed on the first frame, a delayed blur wins afterward.

**How to apply:** In the shared live-rotation observer, detect an endpoint at transition start, schedule normal post-frame finalization, and retain focus/controller references until the delayed retry completes or another live field receives focus. Cover single-event rotations, late blur, rapid rotate-back, and sheet/search state identity in widget tests.