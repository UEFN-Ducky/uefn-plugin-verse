---
description: "UMG slot layout — canvas anchors and offsets, overlay padding, box size rules, grid row and column, ZOrder"
metadata:
  order: 67
  label: "UMG slots"
  default_enabled: false
  load_condition: "Setting UMG anchors, offsets, alignment, ZOrder, padding, or grid cells"
---

## UMG slots

`build_widget_tree` slot JSON and `set_widget_slot` use the same shape. `get_widget_blueprint_info` → `slots` reads anchors, offsets, alignment, and `z_order` back.

### Canvas slot

Point anchor (a corner, edge, or center): `min` equals `max`. Offsets are position and size: left/top are the offset from the anchor, right/bottom are the size.

Stretch: `min` and `max` differ. Offsets are margins from the stretched edges.

```json
{"anchors": {"min": [0.5, 0.5], "max": [0.5, 0.5]}, "offsets": {"left": -220, "top": -70, "right": 220, "bottom": 70}, "alignment": [0.5, 0.5], "z_order": 10}
```

`alignment` is the pivot inside the slot, 0–1. `z_order` is the paint order. `auto_size` sizes to content.

Nine presets (min and max):

| Preset | min | max |
|--------|-----|-----|
| Top-left | 0,0 | 0,0 |
| Top-center | 0.5,0 | 0.5,0 |
| Top-right | 1,0 | 1,0 |
| Center-left | 0,0.5 | 0,0.5 |
| Center | 0.5,0.5 | 0.5,0.5 |
| Center-right | 1,0.5 | 1,0.5 |
| Bottom-left | 0,1 | 0,1 |
| Bottom-center | 0.5,1 | 0.5,1 |
| Bottom-right | 1,1 | 1,1 |
| Fill | 0,0 | 1,1 |

A full-screen hit target is one widget on one layer. Two stacked buttons both receive the click.

### Overlay, border, size box

`padding` `{left, top, right, bottom}` plus `horizontal_alignment` and `vertical_alignment` (`HAlign_Fill`, `HAlign_Center`, `VAlign_Center`, `VAlign_Fill`, …).

### Box slot

Same padding and alignment, plus `size` rule: `auto` or `fill`. Shop stacks use the box distribution on the parent.

### Grid slot

`row`, `column`, `row_span`, `column_span`, `layer`.

### Scroll slot

Padding only. Do not invent a Verse scroll-offset call.
