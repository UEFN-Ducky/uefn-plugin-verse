---
description: "creative_device pattern — @editable fields, OnBegin, subscribing to device/player events, agents vs players, GetPlayspace, and the wrapper helpers"
metadata:
  order: 7
  label: "Devices, @editable & events"
  default_enabled: false
  load_condition: "Writing a placed device — @editable wiring, OnBegin, subscribing to triggers/buttons/player events, or working with agent/player/fort_character"
---

## Devices, `@editable` & events

A gameplay device is a `class(creative_device)`. UEFN instantiates it when placed;
it drives everything through its `@editable` references and `OnBegin`.

### Skeleton

```verse
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

buy_with_currency := class(creative_device):
    @editable Buttons : []button_device = array{}
    @editable ItemGranter : item_granter_device = item_granter_device{}
    @editable var Price : int = 100
    Message<localizes>(String : string):message = "{String}"

    OnBegin<override>()<suspends> : void =
        for (Button : Buttons):
            Button.InteractedWithEvent.Subscribe(BuyWithCurrency)

    BuyWithCurrency(Agent : agent) : void =
        ItemGranter.GrantItem(Agent)
        SuccessHudMessage.SetText(Message("Purchase Successful!"))
        SuccessHudMessage.Show(Agent)
```

### `@editable` — the Details-panel surface

For `@editable audio_player_device` (horns / SFX): place a Fortnite Creative
**Audio Player** in the level first —
`skill_read_subskill("uefn", "creative_devices")` — never Speakers or prop meshes.

`@editable` exposes a field in the UEFN editor so a designer wires it to a placed
device/prop. Every `@editable` needs a **default** (that's why device/struct refs
are `= trigger_device{}` etc., and optionals are `= false`).

| Pattern | Use |
|---------|-----|
| `@editable Trigger : trigger_device = trigger_device{}` | single device reference |
| `@editable Buttons : []button_device = array{}` | a **list** of devices |
| `@editable var Price : int = 100` | editor-tunable **and** mutable at runtime |
| `@editable MaybePlayerManager : ?player_manager = false` | optional ref (may be left unset) |
| `@editable Timers : prop_game_timers = prop_game_timers{}` | a `struct<concrete>` grouping many refs |

Group related references into a `struct<concrete>()` (see `classes`) so one
`@editable` exposes a whole bundle — e.g. a `round_timers` struct holding every
`timer_device`, or a `team_devices` struct holding a team's granters and messages.

> Wiring the *actual* placed references (which prop/device a field points to) is
> done in UEFN or with MCP `wire_verse_device_ref` / `set_verse_editable` (**one
> field per turn** — never parallel wire/spawn;
> `skill_read_subskill("uefn", "batch_commands")`) when the listener is
> online — **not** by writing paths in source. The source only declares the field.

### `OnBegin` — the entry point

`OnBegin<override>()<suspends> : void =` runs once when the device starts. It's
async, so subscribe to events and `spawn` your loops here.

### Subscribing to events

`Event.Subscribe(Handler)` registers a handler called each time the event fires.
Note the two shapes — a plain **field** vs an accessor **method** `()`:

```verse
Trigger.TriggeredEvent.Subscribe(OnActivated)             # device event = field
PrizeButton.InteractedWithEvent.Subscribe(OnPressed)
Spawner.EliminatedEvent.Subscribe(OnNPCEliminated)
GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)  # playspace = method()
GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerRemoved)
FortChar.EliminatedEvent().Subscribe(OnEliminated)          # character = method()
```

The exact event name and whether it's `Event` or `Event()` comes from the
**digest** — search it (`search_verse_digest("trigger_device")`) rather than
guessing. Handler signatures are usually `(Agent : agent)` or `(Agent : ?agent)`.

To wait for a single occurrence instead of subscribing, use `.Await()` in a
`<suspends>` context (see the `async` reference).

### agent vs player vs fort_character

Three related identities — convert deliberately:

| Type | Is | Get from |
|------|----|----------|
| `agent` | Any actor that can act (player or NPC); what events hand you. | event handlers |
| `player` | A human participant; key for persistence `weak_map`s. | `player[Agent]` (failable) |
| `fort_character` | The in-world pawn (position, health, stasis). | `Player.GetFortCharacter[]` / `Agent.GetFortCharacter[]` (failable) |

```verse
if:
    RealAgent := Agent?               # ?agent -> agent
    Player := player[RealAgent]       # agent -> player (fails if not a player)
    Player.IsActive[]
then:
    if (FC := Player.GetFortCharacter[]):   # player -> fort_character
        FC.PutInStasis(stasis_args{ AllowFalling := false })
```

- `GetPlayspace()` → the match; `.GetPlayers()`, `.PlayerAddedEvent()`,
  `.GetTeamCollection()` hang off it.
- `Self.GetPlayspace()` inside a device works too.

### Messages (on-screen text)

Declare a tiny `<localizes>` helper and pass built messages to HUD/UI devices:

```verse
Message<localizes>(String : string):message = "{String}"
# …
ErrorHudMessage.SetText(Message("Not enough {CurrencyName}!"))
ErrorHudMessage.Show(Agent)
```

Some devices expect `message`, others plain `string` — the digest signature tells
you which.

### Cross-device references

A device can hold a ref to another device/manager and call its public API:

```verse
@editable MyPlayerManager : player_manager = player_manager{}
# …
AllPlayers := MyPlayerManager.GetAllGamePlayers()
if (MyPlayer := AllPlayers[Agent]):
    MyPlayer.Services.EconomyManager.RemoveCurrency(CurrencyName, Price)
```

This is how you layer systems (wallet, level, playtime) under a central
`player_manager` / `game_player`. Keep those calls to `<public>` methods. See
`sys_architecture` for the full pattern.
