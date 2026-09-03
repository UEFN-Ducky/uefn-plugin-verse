# SETUP: Place this creative_device in the level. Wire any @editable devices in Details.
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

device_onbegin_example := class(creative_device):

    OnBegin<override>()<suspends>:void =
        Print("device_onbegin_example OnBegin")
