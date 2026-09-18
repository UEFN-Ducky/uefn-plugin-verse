# SETUP: Conveyor belt on a plot. Waypoint props mark dropper link slots.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

conveyor_purchaseable <public> := class<concrete>(purchaseable):
    @editable Waypoints <public> : []creative_prop = array{}
    var LinkedCount <public> : int = 0

    Activate<override>()<suspends> : void =
        ShowRevealProps()
        ShowWaypoints()
        StartGrantLoop()

    ShowWaypoints<public>() : void =
        for (Prop : Waypoints):
            if (Prop.TeleportTo[Prop.GetTransform().Translation, Prop.GetTransform().Rotation]) {}

    LinkDropper<public>(Dropper : dropper_purchaseable, WaypointIndex : int) : void =
        set LinkedCount = LinkedCount + 1
        if (Prop := Waypoints[WaypointIndex]):
            if (Prop.TeleportTo[Prop.GetTransform().Translation, Prop.GetTransform().Rotation]) {}

    UnlinkDropper<public>(Dropper : dropper_purchaseable) : void =
        if (LinkedCount > 0):
            set LinkedCount = LinkedCount - 1

    OnRebirth<override>() : void =
        set LinkedCount = 0
        (super:)OnRebirth()
