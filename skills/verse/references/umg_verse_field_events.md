---
description: "Verse field events in UMG (39.40+) — event() fields bound to Button OnClicked, Subscribe from Verse, event_subscription + AwaitForEvent helper, double-subscribe fix"
metadata:
  order: 62
  label: "UMG Verse field events (39.40+)"
  default_enabled: false
  load_condition: "Handling UMG button clicks / hover via Verse field events, or awaiting widget events from Verse"
---

## UMG Verse field events (39.40+)

Starting with **39.40**, UMG Verse fields can be **events**. Bind a Button's **On Clicked** (or similar) to a Verse `event()` field in the widget, then `Subscribe` from your `creative_device`. This replaces the obsolete myth that "Verse cannot get a named button from a UMG widget."

Requires basics from `umg_verse_fields` / `umg_widgets`.

### Author the events in UMG

1. Open `UW_*`. Add Verse field events (e.g. `RandomizeEvent`, `CloseEvent`) in Variables.
2. Select the Button → bind **On Clicked** to the Verse event field (View Bindings / event binding — follow Epic's Verse field events tutorial).
3. Save. Confirm with `get_verse_api("UW_…")` that the event members exist.

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

Put helpers in `Verse/UMGWidget/widget_event_helpers.verse` — not at Verse root. Confirm `event(t).Await` / exact signatures with digests before shipping.

### Related

- Data fields: `umg_verse_fields`
- Template: `verse_template_apply("umg_widget")`
