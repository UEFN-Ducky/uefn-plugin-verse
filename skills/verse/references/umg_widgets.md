---
description: "UMG User Widgets in UEFN — when to use UMG vs Verse canvas, creating UW_* widgets, Assets digest lookup, AddWidget/RemoveWidget, per-player traps, myths vs the live digest"
metadata:
  order: 60
  label: "UMG User Widgets — proper Verse usage"
  default_enabled: false
  load_condition: "Creating or driving a UMG User Widget / Widget Blueprint from Verse — designer UI, Verse fields, or when deciding UMG vs canvas"
---

## UMG User Widgets — proper Verse usage

A Widget Blueprint is a nested tree plus slots, brushes, animations, and Verse fields. Author those with the tools in `umg_mcp_tools`. The Verse type is the Assets digest name after the asset exists. Do not invent `MyUMGWidget := class` or `card_widget_bp := class`.

Load the reference for the layer you are writing:

| Layer | Reference |
|-------|-----------|
| Which class | `umg_palette` |
| Anchors, ZOrder | `umg_slots` |
| Brush, visibility, transform | `umg_style` |
| Hierarchy | `umg_layout` |
| UI materials | `umg_ui_materials` |
| Highlight / loop keys | `umg_animations` |
| Fields | `umg_verse_fields` |
| Clicks | `umg_verse_field_events` |
| Bindings | `umg_view_bindings` |
| Gamepad | `umg_navigation` |
| Nested widgets | `umg_compose` |
| Finished builds | `umg_recipes` |

### UMG vs Verse canvas

| Choose | When |
|--------|------|
| **Verse canvas** | 6 or fewer controls on one popup |
| **Widget Blueprint `UW_*`** | More than 6 controls. Required above 12. Also for material buttons and Widget Animations |
| **One card instanced in a stack** | Repeating rows. Do not hand-place N buttons |

Both end the same way: `GetPlayerUI[Player].AddWidget(...)`.

### Create the widget asset

**Via tools:** `list_widget_classes` → `build_widget_tree` (omit `folder` so the listener pins `{content_root}/UI`). Then animations, fields, and bindings from `umg_mcp_tools`. Read back with `get_widget_blueprint_info`. Verse cannot call `PlayAnimation` by name — key the animation and bind it (`umg_animations`).

**Preview in editor (v42.20):** interact with the widget in the UMG designer —
do not Launch Session just to check animation / button text. Multiple in-world
instances of the same `UW_*` class now all show Verse-bound values.

### Never guess the Verse type — use the Assets digest

After the widget exists and Verse digests refresh:

```
list_verse_types(digest="assets", name_filter="UW_")
get_verse_api("UW_StyleHud")   # exact members = Verse fields + events
```

If the name is not in the Assets digest, it does not exist for Verse yet — do not invent a stub class.

### Show / hide on a player

```verse
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }

# UW_StyleHud comes from Assets digest — not a hand-written empty class
var MyWidget : UW_StyleHud = UW_StyleHud{}

ShowFor(Player : player) : void =
    if (PlayerUI := GetPlayerUI[Player]):
        # HUD: ui_input_mode.None — menus that need clicks: .All
        PlayerUI.AddWidget(MyWidget, player_ui_slot{ InputMode := ui_input_mode.None })

HideFor(Player : player) : void =
    if (PlayerUI := GetPlayerUI[Player]):
        PlayerUI.RemoveWidget(MyWidget)
```

You can also call `PlayerUI.AddWidget(MyWidget)` with the default slot. Wrapping the UMG widget in a Verse `canvas` is **optional** — only do it when you need Verse-side `canvas_slot` positioning on top of the UMG layout.

### Per-player trap

One shared `var MyWidget : UW_X = UW_X{}` on a device is a **single instance**. If two players both `AddWidget` the same instance, behavior is wrong. For multiplayer:

- Prefer **one widget instance per player** (map `[agent]UW_X` or create in `ShowFor`), or
- Keep a single spectator/shared HUD only when that is intentional.

### Drive data and clicks

| Need | Subskill |
|------|----------|
| `set MyWidget.Progress = 0.5` / materials / messages | `umg_verse_fields` |
| Button → `Subscribe` once | `umg_verse_field_events` |
| View Bindings / ToText / textures | `umg_view_bindings` |
| UI materials / MI_* | `umg_ui_materials` |
| Tree, slots, animations, fields | `umg_mcp_tools` |
| A finished menu or shop | `umg_recipes` |

Template scaffold: `verse_template_apply("umg_widget")`.

### Myths table (common wrong example vs live digest)

Agents keep meeting a "display UMG from Verse" snippet that is partly obsolete. Correct against the digest — do not repeat the myths:

| Myth / bad pattern | Truth (verified) |
|--------------------|------------------|
| `MyUMGWidget := class:` empty placeholder + `@editable myUMGWidget : ?MyUMGWidget` | **Wrong.** Type is the real `UW_*` from Assets digest. Instantiate with `UW_X{}`. |
| "Verse cannot get a named button from a UMG widget" | **Obsolete since 39.40.** Use **Verse field events** on the widget (`event()` fields bound to the Custom Button's `OnButtonClicked`; creatable by tool since 42.30). |
| Must wrap UMG in a Verse `canvas` to show it | **Optional.** `player_ui.AddWidget(Widget)` / `AddWidget(Widget, player_ui_slot{…})` is enough. |
| `canvas.GetSlots()` / `canvas.SetSlot(...)` | **Do not exist.** Digest: `canvas` has `Slots` (init), `AddWidget(Slot)`, `RemoveWidget(Widget)` only. |
| `SizeToContent` / `ZOrder` on `canvas_slot` | **Real** — both exist on `canvas_slot` in UnrealEngine digest. |
| Verse can call UMG `PlayAnimation` by name | **Not exposed.** Key tracks with `add_animation_keys` and trigger them from a Verse field binding. |
| ScrollBox offset scrubbing from Verse | Limited — you can place scroll widgets; do not assume a Verse "set scroll offset" API without checking digests. |

### Folder layout

Put the device under `Verse/UMGWidget/` (or your UI system folder). Never dump `umg_display_device.verse` at `Content/Verse/` root — see `modules`.
