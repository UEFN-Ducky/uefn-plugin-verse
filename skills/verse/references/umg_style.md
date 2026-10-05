---
description: "UMG widget look — text, brush, visibility, render transform, opacity, focusable"
metadata:
  order: 68
  label: "UMG style"
  default_enabled: false
  load_condition: "Setting UMG text, color, brush, visibility, opacity, or render transform"
---

## UMG style

Widget JSON on `build_widget_tree` `properties`. These are the keys `_apply_widget_props` writes.

| Key | Effect |
|-----|--------|
| `text` | String on a `Text` widget (palette `UEFN_TextBlock_C`) — see `umg_palette` |
| `color` | `[R, G, B, A]` on `ColorAndOpacity` |
| `render_opacity` | 0–1 |
| `visibility` | `Visible`, `Collapsed`, `Hidden`, `HitTestInvisible`, `SelfHitTestInvisible` |
| `brush_material` | Material or instance path. Image calls `set_brush_from_material` |
| `brush_texture` | Texture path |

Visibility swaps a layer without deleting the tree. `Collapsed` frees layout. `Hidden` keeps the slot. `HitTestInvisible` paints and ignores hits.

Render transform is what animations key (`umg_animations`): translation, scale, shear, angle, pivot. Set the rest pose in the tree; key the change on the animation.

`IsFocusable` on a Custom Button is required for gamepad (`umg_navigation`). `ToggleWidgetAsVariable` marks a widget Is Variable when a binding must name it. `build_widget_tree` names every node; bindings use that name.
