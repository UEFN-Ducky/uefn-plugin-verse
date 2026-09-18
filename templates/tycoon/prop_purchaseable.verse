# SETUP: Prop unlock on a plot. Pay via economy; reveal uses underground teleport.
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

prop_purchaseable <public> := class<concrete>(purchaseable):
    Activate<override>()<suspends> : void =
        ShowRevealProps()
        StartGrantLoop()
