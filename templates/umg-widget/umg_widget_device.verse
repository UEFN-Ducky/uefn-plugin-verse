# Device for one UMG User Widget instance per player.
# The widget type is the Assets digest name after build_widget_tree.
# Do not invent card_widget_bp := class. Replace WIDGET with that digest name
# (list_verse_types digest=assets) and uncomment the WIDGET lines.
# Fields: TriggerIntro is a bool (add_verse_field logic). CloseEvent is an event field: Await it
# (add_verse_field type event, then bind_widget_event OnButtonClicked; see umg_verse_field_events).
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }

umg_widget_device := class(creative_device):

    @editable
    ShowVolume : volume_device = volume_device{}

    @editable
    HideVolume : volume_device = volume_device{}

    var WidgetReady : logic = false
    var Shown : [player]logic = map{}

    # WIDGET: var Widgets : [player]UW_CustomButtonMenu = map{}

    OnBegin<override>()<suspends>:void =
        ShowVolume.AgentEntersEvent.Subscribe(OnShow)
        HideVolume.AgentEntersEvent.Subscribe(OnHide)

    OnShow(InAgent : agent):void =
        if (Player := player[InAgent], PlayerUI := GetPlayerUI[Player]):
            EnsureInitialized()
            if (set Shown[Player] = true) {}
            # WIDGET:
            # Widget := UW_CustomButtonMenu{}
            # if (set Widgets[Player] = Widget) {}
            # set Widget.TriggerIntro = true
            # PlayerUI.SetFocus(Widget)
            # PlayerUI.AddWidget(Widget, player_ui_slot{ InputMode := ui_input_mode.All })

    OnHide(InAgent : agent):void =
        if (Player := player[InAgent], PlayerUI := GetPlayerUI[Player]):
            if (set Shown[Player] = false) {}
            # WIDGET:
            # if (Widget := Widgets[Player]):
            #     PlayerUI.RemoveWidget(Widget)

    EnsureInitialized():void =
        if (WidgetReady = true):
            return
        # WIDGET: subscribe once, not on every volume enter.
        # First widget instance's CloseEvent, or read the bool bind_widget_event wrote.
        # spawn{ AwaitForEvent(Widget.CloseEvent, OnClose, event_subscription{}) }  # event fields have no Subscribe
        set WidgetReady = true

    OnClose():void =
        for:
            Player : GetPlayspace().GetPlayers()
            PlayerUI := GetPlayerUI[Player]
        do:
            if (set Shown[Player] = false) {}
            # WIDGET:
            # if (Widget := Widgets[Player]):
            #     PlayerUI.RemoveWidget(Widget)
