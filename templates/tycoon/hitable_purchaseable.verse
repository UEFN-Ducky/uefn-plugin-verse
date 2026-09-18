# SETUP: Hit target. Trigger grants while owned.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

hitable_purchaseable <public> := class<concrete>(purchaseable):
    @editable HitTrigger <public> : trigger_device = trigger_device{}
    var HitHook <public> : ?grant_wrapper = false

    Initialize<override>(Plot : plot_manager, NewType : int, NewIndex : int) : void =
        (super:)Initialize(Plot, NewType, NewIndex)
        Hook := grant_wrapper{Item := Self}
        set HitHook = option{Hook}
        HitTrigger.TriggeredEvent.Subscribe(Hook.OnMaybeAgent)

    Activate<override>()<suspends> : void =
        ShowRevealProps()
        StartGrantLoop()
