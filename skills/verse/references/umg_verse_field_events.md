---
description: "Verse field events in UMG (39.40+, tool-created in 42.30) — add_verse_field type event (≤1 bool/int/float param), Custom Button OnButtonClicked → event field (OnClicked no longer compiles), the widget-editor-open requirement, reflected types event(tuple()) / event(tuple(int)), Await from Verse (no Subscribe), AwaitForEvent helper"
metadata:
  order: 62
  label: "UMG Verse field events (39.40+, 42.30)"
  default_enabled: false
  load_condition: "Handling UMG button clicks / hover via Verse field events, or awaiting widget events from Verse"
---

## UMG Verse field events (39.40+)

UMG Verse fields can be **events**. Bind a Custom Button's click to a Verse event field on the
widget, then **await** that event from your `creative_device`. This replaces the obsolete myth that
"Verse cannot get a named button from a UMG widget." Everything below was verified live in UEFN
42.30 (Oct 2 2026): tool-made widget → event field → button binding → Verse device awaits the click
(0 compile errors), and the binding survives a save + reload from disk.

Requires basics from `umg_verse_fields` / `umg_widgets`.

### Author the click

1. **Make the event field.** `add_verse_field(widget_path, "BuyClicked", "event")` — or with one
   parameter: `add_verse_field(widget_path, "PickedSlot", "event", event_parameters=["int"])`.
   Parameters are `bool`, `int` or `float`, **at most one** (`VerseTypeEditor.MaxEventParametersNumberCreation`
   is 1). Events have no default and are never `var`.
2. **Bind the button.** `bind_widget_event(widget_path, "BuyButton", "OnButtonClicked", "BuyClicked")`.
   On a Custom Button (`UIFrameworkCustomButtonWidget`) only **`OnButtonClicked`**, **`OnButtonHighlight`**,
   **`OnButtonUnhighlight`** compile. `OnClicked`, `OnPressed`, `OnReleased`, `OnHovered`, `OnUnhovered` are
   listed by the editor but fail the compile ("The property path 'BuyButton.OnClicked' is invalid"); the
   tool remaps them. Never report a bind as done when `compiled` is false.
3. **Build Verse**, then confirm the members: `list_verse_types(digest="assets", name_filter="UW_…")`.

**Why the tools open the widget's editor (`verse_ready`)** — in 42.30 a widget's Verse fields only
become real once its asset editor has been opened in the editor session. Before that the event field
is a transient object, so (a) the Assets digest lists the widget with **no members** (Verse: E3506
"Unknown member `BuyClicked`") and (b) a click binding is saved with **no target** (after a reload:
"Event 'BuyButton.On Clicked => Self.<None>()': The event could not be generated"). Ducky's
`add_verse_field` / `edit_verse_field` / `remove_verse_field` / `duplicate_verse_field` /
`bind_verse_field` / `bind_widget_event` open and close the widget's editor once per session
(`verse_ready`: `opened` / `ready` / `already_open`) before changing anything, which fixes both.
If a widget got its fields some other way and Verse still says "Unknown member": `open_asset_in_uefn`
on the widget (or ask the user to open it), then build Verse again. A binding made before that fix
must be made again (`bind_widget_event`).

### Reflected Verse types

| Field | Assets digest | Await gives |
| --- | --- | --- |
| event, no parameter | `BuyClicked<public>:event(tuple()) = external {}` | nothing |
| event with one `int` | `PickedSlot<public>:event(tuple(int)) = external {}` | a one-element tuple: `Picked(0)` |
| value field | `var Price<public>:int = external {}` | — (`set Widget.Price = 10`) |

A UMG event field is a Verse `event`, **not** a `listenable`: it has **no `Subscribe`**
(`Unknown member Subscribe in event(tuple())`). Await it in a loop instead.

### Await from Verse (verified)

```verse
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }

shop_ui_device := class(creative_device):

    OnBegin<override>()<suspends>:void =
        for (Player : GetPlayspace().GetPlayers(), PlayerUI := GetPlayerUI[Player]):
            Widget := UW_Shop{}            # the Assets-digest name of your widget
            set Widget.Price = 10
            PlayerUI.AddWidget(Widget, player_ui_slot{InputMode := ui_input_mode.All})
            spawn{ WatchBuy(Widget) }      # one watcher per widget instance
            spawn{ WatchPick(Widget) }

    WatchBuy(Widget:UW_Shop)<suspends>:void =
        loop:
            Widget.BuyClicked.Await()
            set Widget.Price -= 1

    WatchPick(Widget:UW_Shop)<suspends>:void =
        loop:
            Picked := Widget.PickedSlot.Await()   # event(tuple(int))
            Slot:int = Picked(0)
            Print("Picked slot {Slot}")
```

Replace `UW_Shop` / field names with your digest ids (a widget in another folder module is
`FolderName.UW_Shop`). Interactive UI needs `ui_input_mode.All`. One widget instance per player.

**Start the watcher once per widget instance.** Spawning a second `WatchBuy` for the same widget
(e.g. on every volume enter) makes one click run the handler twice — keep the widget and its watcher
together, or guard with a `var Started : logic`.

### Await helper (cancelable)

For `race` / cancel patterns, ship a small helper class (also in template `umg_widget`):

```verse
event_subscription := class:
    CancelEvent : event() = event(){}
    Cancel():void =
        CancelEvent.Signal()

AwaitForEvent(Event : event(t), Callback(:t):void, Subscription : event_subscription where t : type)<suspends>:void =
    race:
        block:
            Result := Event.Await()
            Callback(Result)
        block:
            Subscription.CancelEvent.Await()
```

Put helpers in `Verse/UMGWidget/widget_event_helpers.verse` — not at Verse root.

### Related

- Data fields: `umg_verse_fields`
- Template: `verse_template_apply("umg_widget")`
