# SETUP: Dropper on a plot. Links to conveyor by index; interval grants through economy.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

dropper_purchaseable <public> := class<concrete>(purchaseable):
    @editable ConveyorIndex <public> : int = 0
    @editable WaypointIndex <public> : int = 0
    @editable DropInterval <public> : float = 2.0
    var LinkedConveyor <public> : int = -1

    Activate<override>()<suspends> : void =
        if (Plot := OwnerPlot?):
            if (Belt := Plot.FindConveyor(ConveyorIndex)?):
                Belt.LinkDropper(Self, WaypointIndex)
                set LinkedConveyor = ConveyorIndex
        Interval := DropInterval
        if (Interval <= 0.0):
            set Interval = 2.0
        Gen := RunId
        loop:
            Sleep(Interval)
            if (RunId <> Gen):
                break
            if (IsOwned = false):
                break
            GrantTick()

    OnRebirth<override>() : void =
        if (Plot := OwnerPlot?):
            if (Belt := Plot.FindConveyor(LinkedConveyor)?):
                Belt.UnlinkDropper(Self)
        set LinkedConveyor = -1
        (super:)OnRebirth()
