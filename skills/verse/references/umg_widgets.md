---
description: "UMG User Widgets in UEFN — when to use UMG vs Verse canvas, creating UW_* widgets, Assets digest lookup, AddWidget/RemoveWidget, per-player traps, myths vs the live digest"
metadata:
  order: 60
  label: "UMG User Widgets — proper Verse usage"
  default_enabled: false
  load_condition: "Creating or driving a UMG User Widget / Widget Blueprint from Verse — designer UI, Verse fields, or when deciding UMG vs canvas"
---

## UMG User Widgets — proper Verse usage

UMG (User Widget / Widget Blueprint) is the **designer-authored** UI path. You build the layout in the UMG editor, then drive it from Verse with **Verse fields** (38.00+) and **Verse field events** (39.40+). Do not invent a fake `MyUMGWidget := class:` placeholder — the widget type comes from the Assets digest after you create the asset.

For pure Verse-built trees (`canvas` / `text_block` / `button_loud`), stay on `ui` → `sys_canvas_cookbook`. For designer visuals, materials, and View Bindings, start here.

### UMG vs Verse canvas

| Choose | When |
|--------|------|
| **UMG User Widget** | Designer layout, UI materials, animations (Auto Play), View Bindings, Verse fields / field events |
| **Verse canvas** | Code-built HUD rows, shops, grids, anything you want fully invented in Verse without a `.uasset` widget |

Both end the same way: `GetPlayerUI[Player].AddWidget(...)`.

### Create the widget asset

**In the editor:** Content Browser → right-click → **User Interface → Widget Blueprint**. Name it `UW_*` (e.g. `UW_StyleHud`). Design Text / Image / ProgressBar / Button widgets. Animations: Animations tab → Details → **Auto Play** if they should run on construct (Verse cannot call PlayAnimation by name — verify with digests / Epic docs if that changes).

**Via MCP tools:** `umg_capabilities` → `get_project_info()` for `content_root` → `create_widget_blueprint(asset_name="UW_StyleHud", folder="/VideoTest/UI")` (or omit `folder` / pass `""` so the listener auto-pins) → scaffold with `add_widget_to_tree` → polish with `open_asset_in_uefn`. Details: `umg_mcp_tools`.

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
| Button → `MyWidget.RandomizeEvent.Subscribe(...)` | `umg_verse_field_events` |
| View Bindings / ToText / textures | `umg_view_bindings` |
| UI materials / MI_* | `umg_ui_materials` |
| MCP create / tree / bindings | `umg_mcp_tools` |

Template scaffold: `verse_template_apply("umg_widget")`.

### Myths table (common wrong example vs live digest)

Agents keep meeting a "display UMG from Verse" snippet that is partly obsolete. Correct against the digest — do not repeat the myths:

| Myth / bad pattern | Truth (verified) |
|--------------------|------------------|
| `MyUMGWidget := class:` empty placeholder + `@editable myUMGWidget : ?MyUMGWidget` | **Wrong.** Type is the real `UW_*` from Assets digest. Instantiate with `UW_X{}`. |
| "Verse cannot get a named button from a UMG widget" | **Obsolete since 39.40.** Use **Verse field events** on the widget (`event()` fields bound to Button OnClicked). |
| Must wrap UMG in a Verse `canvas` to show it | **Optional.** `player_ui.AddWidget(Widget)` / `AddWidget(Widget, player_ui_slot{…})` is enough. |
| `canvas.GetSlots()` / `canvas.SetSlot(...)` | **Do not exist.** Digest: `canvas` has `Slots` (init), `AddWidget(Slot)`, `RemoveWidget(Widget)` only. |
| `SizeToContent` / `ZOrder` on `canvas_slot` | **Real** — both exist on `canvas_slot` in UnrealEngine digest. |
| Verse can call UMG `PlayAnimation` by name | **Not exposed** — use UMG **Auto Play**, Verse field–driven material params, or procedural Verse motion. |
| ScrollBox offset scrubbing from Verse | Limited — you can place scroll widgets; do not assume a Verse "set scroll offset" API without checking digests. |

### Folder layout

Put the device under `Verse/UMGWidget/` (or your UI system folder). Never dump `umg_display_device.verse` at `Content/Verse/` root — see `modules`.
