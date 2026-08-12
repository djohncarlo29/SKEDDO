---
name: Bounded squircle geometry
description: Short cards need corner radii scaled as a group to fit their actual paint rect.
---

Use the app-owned bounded shared-squircle border for card surfaces instead of raw
ContinuousRectangleBorder. Its corners must use the same cubic quarter as
SquircleStadiumBorder; matching only the numeric radius is not enough.

**Why:** Flutter's ContinuousRectangleBorder uses a different curve from the
stadium path, so two shapes labeled 24 px can visibly disagree. It also clamps
each corner independently without scaling adjacent radii when their combined
diameter exceeds the rect width or height.

**How to apply:** keep the global radius unchanged; constrain the effective
per-corner path by rect size, then use the shared cubic quarter for both
decoration/outline and clipper/custom-painter paths. Keep straight edge segments
between corners on multi-row and tall cards.

For shallow controls that should read as pills rather than compressed squircles,
use the app-owned `SquircleStadiumBorder` for both the surface clip and any
matching outline or glow path. It must use a true full-height capsule path with
softened cubic end curves; deriving it from `ContinuousRectangleBorder` produces
a rounded rectangle instead of a pill. Reserve the bounded continuous border
for taller content cards.

**Why:** scaling a shared squircle radius fixes invalid geometry but can still
look like an ordinary rounded rectangle on one-row controls; the user expects
those controls to be visibly capsule-shaped while retaining continuous rather
than circular end-cap curvature. A sampled superellipse path can also create
notches or pointed joins unless every quadrant meets at exact tangent points.

**How to apply:** implement the capsule from four joined cubic quarters, with
zero-length side segments when width exceeds the capsule diameter. Opt into
squircle-stadium geometry only for shallow controls such as search, primary
action buttons, single-row action panels, and collapsed single-row cards; keep
multi-row menus and tall cards on their existing continuous-corner treatment.

Category-only cards in Settings and modal sheets follow the same rule: when the
visible card is a single shallow category row, use `SquircleStadiumBorder` for
both the surface and clip; preserve squircles for multi-row or tall content
cards.

**Why:** category sections can collapse from a grouped list to one visible row,
and the solo state should match the app's other capsule controls without
changing the shape of unrelated modal content.

**How to apply:** make the category-card state drive the shape during animated
row expansion/collapse; do not infer pill geometry solely from a one-child
widget list, since grids and other tall cards may also contain one child.