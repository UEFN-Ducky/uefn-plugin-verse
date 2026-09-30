---
description: "UMG composition of User Widgets — named slots, parent embeds header and details, Verse instances one card per list row"
metadata:
  order: 72
  label: "UMG compose"
  default_enabled: false
  load_condition: "Embedding a User Widget in a parent, filling a Named Slot, or instancing offer rows"
---

## Compose User Widgets

A parent Widget Blueprint embeds child User Widgets for a header, an offer row, and a details pane. Place the child class from `list_widget_classes` (the project's `UW_*_C`) with `build_widget_tree`.

Named slots: `list_named_slots` then `set_named_slot_content` for the one region Verse or a child fills. Do not pre-place 40 cards in that slot.

Dynamic lists:

- Parent holds a stack (`StackBox` or a Verse `stack_box`).
- Verse constructs one child widget per entry and sets that instance's fields.
- Epic's in-island shop keeps the frame, art, headers, and price in UMG, and builds offer rows in Verse `stack_box` / `material_block` when the row count is data.

The details pane is one `UW_OfferDetails`. The row is one `UW_OfferItem`. The parent does not contain a copy of every offer.
