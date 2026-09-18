# SETUP: Shooting-range target. Trigger grants while owned.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

shootable_purchaseable <public> := class<concrete>(purchaseable):
    @editable ShotTrigger <public> : trigger_device = trigger_device{}
    var ShotHook <public> : ?grant_wrapper = false

    Initialize<override>(Plot : plot_manager, NewType : int, NewIndex : int) : void =
        (super:)Initialize(Plot, NewType, NewIndex)
        Hook := grant_wrapper{Item := Self}
        set ShotHook = option{Hook}
        ShotTrigger.TriggeredEvent.Subscribe(Hook.OnMaybeAgent)

    Activate<override>()<suspends> : void =
        ShowRevealProps()
        StartGrantLoop()
