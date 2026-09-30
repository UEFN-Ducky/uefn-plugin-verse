---
description: "UMG composition — one root canvas, Z bands, named layers, nested User Widgets, safe margins, custom button hierarchy"
metadata:
  order: 69
  label: "UMG layout"
  default_enabled: false
  load_condition: "Composing a UMG screen, Z-order bands, or a custom button hierarchy"
---

## UMG layout

One root `CanvasPanel`. The factory already inserts one; `build_widget_tree` reuses it when the spec root is `CanvasPanel`.

Z bands:

| Band | z_order |
|------|---------|
| Background | 0 |
| Content | 10 |
| Chrome | 20 |
| Modal | 30 |

Named layers swap by `visibility` or by adding and removing that child. Do not rebuild the whole tree to hide a pane.

Nested User Widgets for a card, a header, a details pane. The shop keeps the frame in the parent and instances one offer-row widget per entry (`umg_compose`). Do not place twelve unique buttons when the data is a list.

Safe margins: keep text off the screen edge. A centered card uses a point anchor at 0.5, 0.5 with offsets that are the card size.

Custom Button hierarchy from the template:

```
CanvasPanel
  Grid or Overlay          z 10
    Image                  material brush (fill / stroke)
    CustomButton           hit target, IsFocusable
```

The label lives on the Custom Button or a nested User Widget. A separate text widget is not in the palette.

One full-screen hit target per layer.
