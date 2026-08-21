---
name: Offline OCR phase boundary
description: Durable constraints for the app's native offline OCR implementation and completion claims.
---

Native Vision and bundled ML Kit are suitable offline OCR engines, but platform wiring alone is not a completed OCR phase. Android ML Kit bundled text recognition does not expose the same per-line confidence value as Apple Vision; the result must say that confidence is unavailable rather than inventing a numeric score. PDF OCR should receive page indices selected after text-layer quality evaluation, and cancellation needs a native cancel path plus checks between PDF pages. Final claims still require real sample validation on Android and an Apple runtime.

**Why:** Linux-side Dart and Android compilation can validate contracts and wiring, but cannot prove iOS Vision behavior, camera/photo orientation handling, or recognition accuracy across real document classes.

**How to apply:** Keep platform-specific limitations in OCR metadata/warnings, test selection and cancellation at the Dart boundary, and treat device fixtures as the final completion gate.