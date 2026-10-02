---
description: "Four finished UMG builds — HUD message, float binding, custom button menu, shop frame — with the 6 and 12 control rule"
metadata:
  order: 73
  label: "UMG recipes"
  default_enabled: false
  load_condition: "Building a finished UMG menu, HUD, or shop frame"
---

## UMG recipes

Button count on one popup:

- **6 or fewer** controls: Verse canvas (`ui` → `sys_canvas_cookbook` → `sys_custom_buttons`).
- **More than 6:** prefer a Widget Blueprint (`UW_*`).
- **More than 12:** the screen is a Widget Blueprint. Do not stack that many Verse `button_loud` widgets.
- Repeating rows are **one card User Widget instanced in a stack**, not N hand-placed buttons.

The Verse type is the Assets digest name after the asset exists. Do not write `card_widget_bp := class`.

### 1 — HUD message

Image or Custom Button is optional. `add_verse_field` name `Banner`, type `message`. Bind that field to the visible text on a nested User Widget or the button. No click. `InputMode.None`. One instance per player.

### 2 — Slider or progress

`add_verse_field` name `Progress`, type `float`, default `0`. Bind to `RenderOpacity` or a material scalar (`Conv_SetScalarParameter`) when the palette has no `ProgressBar` / `Slider`. Device: `set Widget.Progress = 0.5`.

### 3 — Custom Button menu

Verified live as `UW_CustomButtonMenu`:

```
CanvasPanel Root
  Overlay MenuLayer     anchors 0.5,0.5  offsets ±220 x ±70  z_order 10
    Image ButtonFill    brush_material = UI-domain unlit material
    CustomButton Button1
```

- `Anim_Highlight` on `ButtonFill`, Opacity, keys at 0 (0.45) and 0.35 (1).
- `Anim_Loop` on `ButtonFill`, Transform `ScaleX` and `ScaleY`, keys at 0 (1), 0.4 (1.06), 0.8 (1).
- `add_verse_field` `TriggerIntro` type `logic` (the tool stores `bool`). Bind to `ButtonFill.RenderOpacity` when the intro should fade the fill.
- `add_verse_field` `CloseClicked` type `event` (42.30), then `bind_widget_event` `Button1` `OnButtonClicked` → `CloseClicked` (or → `TriggerIntro` / a close bool). Check `compiled`. In the device, `loop: Widget.CloseClicked.Await()` in one spawned watcher per widget — event fields have no `Subscribe` (`umg_verse_field_events`).
- Highlight graph: `umg_animations`. Device: `umg_widget` template. Volume opens it. `SetFocus` then `InputMode.All`. Remove on leave.

### 4 — Shop frame

Parent User Widget: overlay frame, header, details pane (`UW_OfferDetails`). Offer rows are one `UW_OfferItem` instanced from Verse into a stack, or a Verse `stack_box` of `material_block` inside the UMG frame. Price and title are fields on the row instance. Do not pre-place every offer.
