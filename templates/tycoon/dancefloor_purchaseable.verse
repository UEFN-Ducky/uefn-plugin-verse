# SETUP: Emote / dance volume. Trigger grants while owned.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

dancefloor_purchaseable <public> := class<concrete>(purchaseable):
    @editable DanceTrigger <public> : trigger_device = trigger_device{}
    var DanceHook <public> : ?grant_wrapper = false

    Initialize<override>(Plot : plot_manager, NewType : int, NewIndex : int) : void =
        (super:)Initialize(Plot, NewType, NewIndex)
        Hook := grant_wrapper{Item := Self}
        set DanceHook = option{Hook}
        DanceTrigger.TriggeredEvent.Subscribe(Hook.OnMaybeAgent)

    Activate<override>()<suspends> : void =
        StartGrantLoop()
