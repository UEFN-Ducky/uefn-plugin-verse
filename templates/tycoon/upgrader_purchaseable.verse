# SETUP: Belt upgrader. Multiplies plot GrantToAgent after buy.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

upgrader_purchaseable <public> := class<concrete>(purchaseable):
    @editable Multiplier <public> : float = 2.0
    var Applied <public> : logic = false

    Activate<override>()<suspends> : void =
        if (Applied = false):
            if (Plot := OwnerPlot?):
                set Plot.BeltMultiplier = Plot.BeltMultiplier * Multiplier
                set Applied = true
        StartGrantLoop()

    OnRebirth<override>() : void =
        set Applied = false
        (super:)OnRebirth()
