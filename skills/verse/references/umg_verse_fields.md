---
description: "Verse fields in UMG (38.00+) — declare fields on a User Widget, bind with View Bindings, set from a creative_device, supported types, worked Style1/Style2 example"
metadata:
  order: 61
  label: "UMG Verse fields (38.00+)"
  default_enabled: false
  load_condition: "Driving a UMG User Widget from Verse with Verse fields — Progress, message, material, texture, logic — or following the Epic 38.00 Verse fields tutorial"
---

## UMG Verse fields (38.00+)

Starting with **Fortnite / UEFN 38.00**, you can define **Verse fields** directly on a UMG User Widget. They appear in the Variables panel, bind to widget properties via **View Bindings**, and reflect into the **Assets digest** so Verse can `set MyWidget.Field = value`.

One-way for the initial release: **Verse → widget**. Widget → Verse clicks need **Verse field events** (39.40+) — see `umg_verse_field_events`.

### Author the fields in UMG

1. Open the User Widget (`UW_*`).
2. Open the **Variables** window in the designer.
3. Add Verse fields. Common types (Epic 38.00 notes): `logic`, `int`, `float`, `message`, material, texture.
4. Open **View Bindings** and bind each field to a widget property (text, material, visibility, progress, etc.). Conversion functions: `umg_view_bindings`.
5. Save. Confirm with `get_verse_api("UW_YourWidget")` / `list_verse_types(digest="assets", name_filter="UW_")`.

### Drive from a creative_device

```verse
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }

# Types UW_FieldsTest / MI_* come from Assets digest — never invent stub classes
verse_fields_example := class(creative_device):
    @editable Style1Volume : volume_device = volume_device{}
    @editable Style2Volume : volume_device = volume_device{}
    @editable AddWidgetVolume : volume_device = volume_device{}

    Style1Message<localizes> : message = "Style 1!"
    Style2Message<localizes> : message = "Style 2!"

    var MyWidget : UW_FieldsTest = UW_FieldsTest{}
    var Style1Material : MI_Style1ProgressBar = MI_Style1ProgressBar{}
    var Style2Material : MI_Style2ProgressBar = MI_Style2ProgressBar{}
    var VerseProgressValue : float = 0.0

    OnBegin<override>()<suspends>:void =
        set MyWidget.StyleText = Style1Message
        AddWidgetVolume.AgentEntersEvent.Subscribe(AddWidget)
        Style1Volume.AgentEntersEvent.Subscribe(EnterStyle1)
        Style2Volume.AgentEntersEvent.Subscribe(EnterStyle2)

    AddWidget(InAgent : agent):void =
        for:
            Player:GetPlayspace().GetPlayers()
            PlayerUI := GetPlayerUI[Player]
        do:
            PlayerUI.AddWidget(MyWidget)
            Print("Widget added")

    EnterStyle1(InAgent : agent):void =
        set MyWidget.ProgressBarMaterial = Style1Material
        if (VerseProgressValue < 1.0):
            set VerseProgressValue += 0.1
        set MyWidget.ProgressValue = VerseProgressValue
        set MyWidget.StyleText = Style1Message

    EnterStyle2(InAgent : agent):void =
        set MyWidget.ProgressBarMaterial = Style2Material
        if (VerseProgressValue < 1.0):
            set VerseProgressValue += 0.1
        set MyWidget.ProgressValue = VerseProgressValue
        set MyWidget.StyleText = Style2Message
```

Replace `UW_FieldsTest` / `MI_*` / field names with **exact** digest identifiers from your project.

### Rules that keep this working

- Field names in Verse must match the UMG Verse-field names (digest is authoritative).
- `message` fields: use `<localizes>` helpers or `message` literals — plain `string` will not type-check where `message` is required.
- Materials / textures: use the Verse ids from Assets digest (`MI_*`, texture names), usually created from `Fortnite > UI > Material` (see `umg_ui_materials`).
- Updates apply when you `set` the field after the widget is on a `player_ui`. Binding re-eval is View Bindings' job — if nothing changes, check the binding direction and conversion function.
- Multiplayer: one shared widget instance is a trap — see `umg_widgets`.

### Related

- Events from buttons: `umg_verse_field_events`
- Binding / ToText / textures: `umg_view_bindings`
- MCP inspect of member vars: `get_widget_blueprint_info`
