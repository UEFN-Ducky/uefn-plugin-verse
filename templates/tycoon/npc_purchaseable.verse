# SETUP: NPC buyable. Enable npc_spawner_device; KillTrigger grants via economy.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

npc_purchaseable <public> := class<concrete>(purchaseable):
    @editable Spawner <public> : npc_spawner_device = npc_spawner_device{}
    @editable KillTrigger <public> : trigger_device = trigger_device{}
    var KillHook <public> : ?grant_wrapper = false

    Initialize<override>(Plot : plot_manager, NewType : int, NewIndex : int) : void =
        (super:)Initialize(Plot, NewType, NewIndex)
        Hook := grant_wrapper{Item := Self}
        set KillHook = option{Hook}
        KillTrigger.TriggeredEvent.Subscribe(Hook.OnMaybeAgent)

    Activate<override>()<suspends> : void =
        Spawner.Enable()
        Spawner.Reset()
        Spawner.Spawn()
        StartGrantLoop()
