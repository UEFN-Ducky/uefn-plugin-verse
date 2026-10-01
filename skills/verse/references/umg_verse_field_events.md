---
description: "Verse field events in UMG (39.40+, creatable by tool in 42.30) — add_verse_field type event (≤1 bool/int/float param), Custom Button OnButtonClicked → event field (OnClicked no longer compiles), Subscribe from Verse, event_subscription + AwaitForEvent helper, double-subscribe fix"
metadata:
  order: 62
  label: "UMG Verse field events (39.40+, 42.30)"
  default_enabled: false
  load_condition: "Handling UMG button clicks / hover via Verse field events, or awaiting widget events from Verse"
---

## UMG Verse field events (39.40+)

Starting with **39.40**, UMG Verse fields can be **events**. Bind a Button's **On Clicked** (or similar) to a Verse `event()` field in the widget, then `Subscribe` from your `creative_device`. This replaces the obsolete myth that "Verse cannot get a named button from a UMG widget."

Requires basics from `umg_verse_fields` / `umg_widgets`.

### Author the click (42.30 — verified live Oct 1 2026)

1. **Make the event field.** `add_verse_field(widget_path, "BuyClicked", "event")` — or with one
   parameter: `add_verse_field(widget_path, "PickedSlot", "event", event_parameters=["int"])`.
   Event parameters are `bool`, `int` or `float`, **at most one** (`VerseTypeEditor.MaxEventParametersNumberCreation`
   is 1; two are refused). Events have no default and are never `var`. Before 42.30 the tool could not
   create events — then bind to a bool/int instead (path 3).
2. **Bind the button.** `bind_widget_event(widget_path, "BuyButton", "OnButtonClicked", "BuyClicked")`.
   On a Custom Button (`UIFrameworkCustomButtonWidget`) only **`OnButtonClicked`**, **`OnButtonHighlight`**,
   **`OnButtonUnhighlight`** compile. `OnClicked`, `OnPressed`, `OnReleased`, `OnHovered`, `OnUnhovered` are
   listed by the editor but fail the compile ("The property path 'BuyButton.OnClicked' is invalid") — the
   tool remaps them and returns `compiled` / `compile_error`; never report a bind as done when
   `compiled` is false. An `event(int)` destination compiles with `OnButtonClicked` too.
3. **No event field?** Bind the click to a `bool` / `int` field the device watches (works the same way).

**Check before you say it works (HARD):**
- The binding can be **dropped when the editor reloads the widget** (seen in 42.30: after a reload the
  compile warns "The event could not be generated" and the binding list is empty). After a reload or
  editor restart, run `bind_widget_event` again and check `compiled`.
- Verse sees widget fields only through the **Assets digest**. In the 42.30 test, fields made by the tool
  were on the widget (`list_verse_fields`) but not yet in the digest after save + Verse build, so Verse got
  E3506 "Unknown member `BuyClicked`". After building, confirm with
  `list_verse_types(digest="assets", name_filter="UW_…")`. If the members are missing, ask the user to
  open the widget in the UMG editor, press **Compile** and **Save**, then **Verse → Build Verse Code**, and
  check again before writing Verse that uses them.

Do not invent a second widget to get a click.

### Subscribe from Verse (do this once)

```verse
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Random }

verse_fields_events_example := class(creative_device):
    @editable MyVolume : volume_device = volume_device{}

    var FancyRandomizerWidget : UW_FieldsTest = UW_FieldsTest{}
    var ProgressBarMaterial : MI_MeterTest = MI_MeterTest{}
    var WidgetReady : logic = false

    OnBegin<override>()<suspends>:void =
        MyVolume.AgentEntersEvent.Subscribe(AddWidgetsToPlayers)

    AddWidgetsToPlayers(InAgent : agent):void =
        for:
            Player:GetPlayspace().GetPlayers()
            PlayerUI := GetPlayerUI[Player]
        do:
            EnsureInitialized()
            PlayerUI.AddWidget(FancyRandomizerWidget, player_ui_slot{ InputMode := ui_input_mode.All })

    # CRITICAL: subscribe once — not every volume enter
    EnsureInitialized():void =
        if (WidgetReady = true):
            return
        set FancyRandomizerWidget.Progress = 0.0
        set FancyRandomizerWidget.MyMaterial = ProgressBarMaterial
        set FancyRandomizerWidget.ShowTexture = false
        FancyRandomizerWidget.RandomizeEvent.Subscribe(OnRandomize)
        FancyRandomizerWidget.CloseEvent.Subscribe(RemoveWidgetFromPlayers)
        set WidgetReady = true

    RemoveWidgetFromPlayers():void =
        for:
            Player:GetPlayspace().GetPlayers()
            PlayerUI := GetPlayerUI[Player]
        do:
            PlayerUI.RemoveWidget(FancyRandomizerWidget)

    OnRandomize():void =
        set FancyRandomizerWidget.Progress = GetRandomFloat(0.0, 1.0)
        if (GetRandomInt(0, 1) = 1):
            spawn { ShowSurpriseTexture() }

    ShowSurpriseTexture()<suspends>:void =
        set FancyRandomizerWidget.ShowTexture = true
        Sleep(1.0)
        set FancyRandomizerWidget.ShowTexture = false
```

Replace `UW_FieldsTest` / field names with your digest ids. Interactive UI needs `ui_input_mode.All`.

### Double-subscribe bug (Epic sample + fix)

Epic's sample calls `InitializeWidget()` (which `Subscribe`s) on **every** volume enter. That stacks handlers — one click fires N times.

| Wrong | Right |
|-------|-------|
| Subscribe inside every `AddWidgetsToPlayers` | Guard with `var WidgetReady : logic` (or unsubscribe) so Subscribe runs once |

### Await helper (optional)

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

Put helpers in `Verse/UMGWidget/widget_event_helpers.verse` — not at Verse root. `event(t).Await` signatures are as shown — the error list flags any drift.

### Related

- Data fields: `umg_verse_fields`
- Template: `verse_template_apply("umg_widget")`
