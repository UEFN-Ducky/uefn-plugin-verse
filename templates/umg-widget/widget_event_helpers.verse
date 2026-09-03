# SETUP: Shared helpers for UMG Verse field events (39.40+).
# Apply with verse_template_apply("umg_widget") — lands in Verse/UMGWidget/.
# Confirm event(t).Await / race shapes against digests if your build differs.
using { /Verse.org/Simulation }

event_subscription := class:
    CancelEvent : event() = event(){}

    Cancel():void =
        CancelEvent.Signal()

# Holds until Event signals or Subscription.Cancel() wins the race.
AwaitForEvent(Event : event(t), Callback(:t):void, Subscription : event_subscription where t : type)<suspends>:void =
    race:
        block:
            Result := Event.Await()
            Callback(Result)
        block:
            Subscription.CancelEvent.Await()
