---
description: "Building UEFN UI in Verse — canvas, overlay, stack_box and their slots, text_block/texture_block/color_block widgets, alignment, padding/margin, canvas-builder pattern, and where to invent full screens"
metadata:
  order: 10
  label: "Building UI — canvas & widgets"
  default_enabled: false
  load_condition: "Creating on-screen UI/HUD widgets — canvas, overlay, stack_box, text_block, texture_block, alignment or slots"
---

## Building UI — canvas & widgets

Verse UI is a **tree of widgets in slots**. You build a `canvas`, add it to a
player's screen with `AddWidget`, and update `text_block`/`texture_block` fields
at runtime. Isolate construction in a `*_canvas_builder` class — keep layout there
and game logic elsewhere.

### Verse canvas vs UMG User Widget

| Path | Load |
|------|------|
| Code-built HUD / shop / grid (`canvas`, `text_block`, …) | this file → `sys_canvas_cookbook` → `sys_hud_template` / `sys_ui_menus` |
| Designer Widget Blueprint (`UW_*`) + Verse fields / events | **`umg_widgets`** → `umg_verse_fields` / `umg_verse_field_events` / `umg_view_bindings` |

Both use `GetPlayerUI` + `AddWidget`. Do not invent a fake `MyUMGWidget := class:` stub — UMG types come from the Assets digest.

**Inventing a full shop / inventory / modal / grid from scratch?** Load
`sys_canvas_cookbook` first (compositions + visibility checklist), then
`sys_hud_template` (ShowHUD wiring) or `sys_ui_menus` (interactive `.All`).

```verse
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
```

### The container / slot rule

Each container widget has a `Slots := array:` of **its own** slot type. Never mix
them:

| Container | Slot type | Extra field |
|-----------|-----------|-------------|
| `canvas` | `canvas_slot` | `Anchors`, `Offsets` (screen-space placement) |
| `overlay` | `overlay_slot` | stacks children on top of each other |
| `stack_box` | `stack_box_slot` | `Orientation := orientation.Horizontal`/`.Vertical` |

Every slot carries a `Widget := <child>` plus alignment/padding.

### Leaf widgets

| Widget | Use |
|--------|-----|
| `text_block` | dynamic text — hold a `var` and call `.SetText(Message(...))` |
| `texture_block` | an image; set `DefaultImage := Textures.T_Empty` and `DefaultDesiredSize := vector2{X:=…, Y:=…}` |
| `color_block` | solid fill / progress bar / dim backdrop — set `DefaultColor` + `DefaultDesiredSize` |
| `button_loud` / `button_regular` | clickable — only useful with `ui_input_mode.All`; confirm in digest |

Store the leaves as fields so logic can update them later:

```verse
top_hud_canvas_builder <public> := class():
    var TimerText : text_block = text_block{}
    var HUDBackground : texture_block = texture_block{
        DefaultImage := Textures.T_Empty
        DefaultDesiredSize := vector2{X := 400.0, Y := 60.0}
    }
```

### Alignment & spacing (on each slot)

```verse
HorizontalAlignment := horizontal_alignment.Center   # .Left .Center .Right .Fill
VerticalAlignment   := vertical_alignment.Top         # .Top .Center .Bottom .Fill
Padding := margin{ Left := 0.0, Top := 45.0, Right := 20.0, Bottom := 0.0 }
```

`canvas_slot` positions via `Anchors` (fractions of the screen) instead of
padding:

```verse
canvas_slot:
    Anchors := anchors{ Minimum := vector2{X:=0.0, Y:=0.0}, Maximum := vector2{X:=1.0, Y:=1.0} }
    Widget := overlay: …
```

### A nested tree (a top-bar HUD)

```verse
CreateCanvas() : canvas =
    Canvas : canvas = canvas:
        Slots := array:
            canvas_slot:
                Anchors := anchors{ Minimum := vector2{X:=0.0,Y:=0.0}, Maximum := vector2{X:=1.0,Y:=1.0} }
                Widget := overlay:
                    Slots := array:
                        overlay_slot:
                            HorizontalAlignment := horizontal_alignment.Center
                            VerticalAlignment := vertical_alignment.Top
                            Widget := stack_box:
                                Orientation := orientation.Horizontal
                                Slots := array:
                                    stack_box_slot:
                                        Widget := PlayerTexture
                                    stack_box_slot:
                                        Widget := Team1CountText
    return Canvas
```

### Builder pattern (separate layout from data)

The builder takes its leaves from the **owning manager** via a
`SetUIElements(...)` method, then `CreateCanvas()` assembles them — so the
manager owns the `text_block`s and updates them, while the builder only
arranges:

```verse
SetUIElements<public>(InTimerText : text_block, InBackground : texture_block, …) : void =
    set TimerText = InTimerText
    set HUDBackground = InBackground
```

### Showing & updating (must show visually)

```verse
Message<localizes>(String : string) : message = "{String}"

ShowFor(Agent : agent) : void =
    if (Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
        set MyCanvas = CanvasBuilder.CreateCanvas()
        PlayerUI.AddWidget(MyCanvas, player_ui_slot{ InputMode := ui_input_mode.None })
        # or ui_input_mode.All for shops / popups
```

- Update live by mutating the stored leaf: `TimerText.SetText(Message("{Time}"))`.
- Remove with `PlayerUI.RemoveWidget(MyCanvas)`.
- If nothing appears: run the visibility checklist in `sys_canvas_cookbook`.

Compositions (shop rows, inventory grids, modals, progress bars, dynamic cells):
**`sys_canvas_cookbook`**. Manager ShowHUD recipe: **`sys_hud_template`**. Interactive
menus: **`sys_ui_menus`**.

### Gotchas

- Wrong slot type in a container (e.g. `overlay_slot` inside a `stack_box`) → won't
  compile. Match the table above.
- Sizes/positions are `float` — write `400.0`, never `400`.
- Don't rebuild the whole canvas every frame; build once, mutate the leaves.
- Zero-size leaves or missing `AddWidget` → invisible UI (not a compile error).
