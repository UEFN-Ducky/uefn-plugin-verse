---
description: "Party-aware gameplay (Social Synergy API, v42.10) — GetLocalParty, party size, same-party checks, join/leave events, party-only access, difficulty that scales with party size"
metadata:
  order: 13
  label: "Party / Social Synergy API (v42.10)"
  default_enabled: false
  load_condition: "Anything about parties, squads of friends, party bonuses, party-only doors, scaling difficulty to group size, or detecting who joined together"
---

## Party-aware gameplay — Social Synergy API (v42.10)

Players can form parties across the Epic ecosystem; since v42.10 Verse can read a
player's party. Everything below is verified against the 42.10 digest.

```verse
using { /UnrealEngine.com/Social }     # GetLocalParty, party_member_info
using { /Verse.org/AgentGroup }        # agent_group_interface
```

### The API (digest)

| Symbol | Where | Signature |
|--------|-------|-----------|
| `Player.GetLocalParty()` | `/UnrealEngine.com/Social` | `(InPlayer : player).GetLocalParty()<reads> : agent_group_interface(party_member_info)` |
| `party_member_info` | `/UnrealEngine.com/Social` | per-member info class (no public fields yet; Epic says more later) |
| `GetMemberMap()` | `agent_group_interface` | `()<reads> : [agent]party_member_info` |
| `AddMemberEvent` | field | `listenable(tuple(agent, party_member_info))` |
| `RemoveMemberEvent` | field | `listenable(tuple(agent, party_member_info))` |
| `MemberInfoChangeEvent` | field | `listenable(tuple(agent, party_member_info))` |

Facts that shape the design:

- A player is **always** in a party of at least one (themselves), so `GetLocalParty()` never fails and needs no `if`.
- The party is filtered to the **current session**: members not in this island are not in the map.
- `agent_group_interface` is `<unique>`, so two players' parties can be compared with `=`.
- `GetLocalParty` and `GetMemberMap` are `<reads>`: safe inside `if (…)` heads and `<transacts>` helpers.
- The events are **fields** (`Party.AddMemberEvent.Subscribe(…)`), not `()` methods.

### Helpers you will reuse

```verse
PartySize(Player : player)<reads> : int =
    Player.GetLocalParty().GetMemberMap().Length

SameParty(A : player, B : player)<reads><decides> : void =
    A.GetLocalParty() = B.GetLocalParty()

PartyMates(Player : player)<reads> : []agent =
    for (Member -> Info : Player.GetLocalParty().GetMemberMap(), Member <> Player):
        Member
```

### Device: party bonus, party-only door, scaled difficulty

```verse
using { /Fortnite.com/Devices }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Social }
using { /Verse.org/AgentGroup }

party_gameplay_device := class(creative_device):
    # Door / area only members of the same party as the owner may open.
    @editable PartyDoorTrigger : trigger_device = trigger_device{}
    @editable PartyDoor : barrier_device = barrier_device{}
    # Score bonus per extra party member on each elimination.
    @editable BonusPerMate : int = 5
    # Difficulty knob other devices read: 1.0 solo, +25 % per extra member.
    var DifficultyScale : float = 1.0
    var DoorOwner : ?player = false
    var PartySubs : [player][]cancelable = map{}

    OnBegin<override>()<suspends> : void =
        Playspace := GetPlayspace()
        for (Player : Playspace.GetPlayers()):
            OnPlayerJoined(Player)
        Playspace.PlayerAddedEvent().Subscribe(OnPlayerJoined)
        Playspace.PlayerRemovedEvent().Subscribe(OnPlayerLeft)
        PartyDoorTrigger.TriggeredEvent.Subscribe(OnDoorTriggered)

    OnPlayerJoined(Player : player) : void =
        Party := Player.GetLocalParty()
        AddSub := Party.AddMemberEvent.Subscribe(OnPartyChanged)
        RemoveSub := Party.RemoveMemberEvent.Subscribe(OnPartyChanged)
        if (set PartySubs[Player] = array{AddSub, RemoveSub}) {}
        if (not DoorOwner?):
            set DoorOwner = option{Player}
        RecomputeDifficulty()

    OnPlayerLeft(Player : player) : void =
        if (Subs := PartySubs[Player]):
            for (Sub : Subs):
                Sub.Cancel()
        var Next : [player][]cancelable = map{}
        for (K -> V : PartySubs, K <> Player):
            if (set Next[K] = V) {}
        set PartySubs = Next
        RecomputeDifficulty()

    OnPartyChanged(Arg : tuple(agent, party_member_info)) : void =
        RecomputeDifficulty()

    # Largest party in the session drives difficulty.
    RecomputeDifficulty() : void =
        var Largest : int = 1
        for (Player : GetPlayspace().GetPlayers()):
            Size := Player.GetLocalParty().GetMemberMap().Length
            if (Size > Largest):
                set Largest = Size
        set DifficultyScale = 1.0 + 0.25 * ((Largest - 1) * 1.0)

    OnDoorTriggered(MaybeAgent : ?agent) : void =
        if (Agent := MaybeAgent?, Player := player[Agent], Owner := DoorOwner?):
            if (Player.GetLocalParty() = Owner.GetLocalParty()):
                PartyDoor.Disable()
            else:
                PartyDoor.Enable()

    # Called by your scoring system: bonus scales with party mates present.
    EliminationBonus(Killer : player)<reads> : int =
        Mates := Killer.GetLocalParty().GetMemberMap().Length - 1
        BonusPerMate * Mates
```

### Other recipes (same primitives)

- **Reduced friendly fire between party members:** on `DamagedEvent`, cast the
  instigator to a player and skip or scale damage when `SameParty[Victim, Attacker]`.
- **Team balancing:** iterate `GetPlayers()`, bucket by `GetLocalParty()`, then
  `AddToTeam[]` bucket by bucket (`sys_teams`) so parties stay together or are split.
- **Party UI / commentary:** show `PartySize` on the HUD and react to
  `AddMemberEvent` / `RemoveMemberEvent` for "X joined your party" text.

### Gotchas

- `party_member_info` has no public fields in 42.10; treat it as opaque.
- Subscribe **once per player** and cancel on leave; the party object outlives the
  session membership.
- `GetMemberMap()` includes the player themself; subtract one for "mates".
- Requires FN ≥ 42.10 (`@available 4210`); older uploads will not compile it.
