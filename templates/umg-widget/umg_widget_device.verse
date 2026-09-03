# SETUP: Device skeleton for a UMG User Widget driven by Verse fields / field events.
# 1. Create UW_* in Content (umg_capabilities → create_widget_blueprint, or designer).
# 2. Add Verse fields + events; bind in View Bindings (see umg_widgets / umg_verse_fields).
# 3. Confirm type name: list_verse_types(digest="assets", name_filter="UW_")
# 4. Uncomment the SETUP blocks below and replace UW_YourWidget / field names.
# 5. Build Verse, place this device, wire volumes if you use them.
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }

umg_widget_device := class(creative_device):

    @editable
    ShowVolume : volume_device = volume_device{}

    var WidgetReady : logic = false

    # SETUP: uncomment after UW_YourWidget exists in Assets digest
    # var MyWidget : UW_YourWidget = UW_YourWidget{}

    OnBegin<override>()<suspends>:void =
        ShowVolume.AgentEntersEvent.Subscribe(OnShow)

    OnShow(InAgent : agent):void =
        EnsureInitialized()
        if (Player := player[InAgent], PlayerUI := GetPlayerUI[Player]):
            # SETUP: uncomment
            # PlayerUI.AddWidget(MyWidget, player_ui_slot{ InputMode := ui_input_mode.All })
            Print("umg_widget_device: show (uncomment SETUP lines after UW_* exists)")

    # Subscribe once — never re-Subscribe on every volume enter (double-fire bug).
    EnsureInitialized():void =
        if (WidgetReady = true):
            return
        # SETUP: set defaults + subscribe to Verse field events
        # set MyWidget.Progress = 0.0
        # MyWidget.CloseEvent.Subscribe(OnClose)
        # MyWidget.RandomizeEvent.Subscribe(OnRandomize)
        set WidgetReady = true

    OnClose():void =
        for:
            Player:GetPlayspace().GetPlayers()
            PlayerUI := GetPlayerUI[Player]
        do:
            # SETUP: PlayerUI.RemoveWidget(MyWidget)
            Print("umg_widget_device: close")

    OnRandomize():void =
        Print("umg_widget_device: randomize")
