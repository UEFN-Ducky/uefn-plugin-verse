---
description: "Spawning & movement — spawning enemies/props, movement loops with MoveTo/nav points, NPC elimination tracking, teleport-until-success, and array-based pools"
metadata:
  order: 26
  label: "Game systems — spawning, movement & AI"
  default_enabled: false
  load_condition: "Spawning enemies/props/waves, moving objects along paths, tracking NPC eliminations, or teleporting players reliably"
---

## Spawning, movement & AI

Names below are generic — adapt them to your entities. All device/prop APIs
(`creative_prop`, `MoveTo`, spawner events) come from the digest.

### An entity class that owns its own behavior

Give each spawned thing a class holding its prop, live state, and an async loop it
drives itself. Kick the loop off with `spawn` from a sync setter:

```verse
spawned_enemy_prop := class<concrete>():
    @editable PropObject <public> : creative_prop = creative_prop{}
    var Health <public> : float = 100.0
    var IsAlive <public> : logic = true
    var IsMoving <private> : logic = false
    var CurrentNavPoint <private> : ?nav_point_data = false

    StartMovement<public>(StartPoint : nav_point_data) : void =
        set CurrentNavPoint = option{StartPoint}
        set IsMoving = true
        spawn{ MovementLoop() }                # sync entry → async loop
```

### Movement loop along nav points

Move with `MoveTo`, `Sleep` for the travel time, advance to the next point, and
`break` at the end or on death:

```verse
MovementLoop<private>()<suspends> : void =
    loop:
        if (not IsAlive? or not IsMoving?): break
        if (NavPoint := CurrentNavPoint?):
            TargetPos := NavPoint.NavPoint.GetTransform().Translation
            PropObject.MoveTo(TargetPos, IdentityRotation(), MoveSpeed)
            Sleep(MoveSpeed)                    # wait out the move
            if (Next := NavPoint.NextNavPoint?):
                set CurrentNavPoint = option{Next}
            else:
                DestroyProp(); break            # reached the end
        else:
            break
```

`MoveTo` / `MoveToLocation` on `creative_prop` are async positioning calls — look
the exact signature up in the digest. For continuous spin, `spawn` a per-prop loop
that nudges the rotation each tick.

### Damage & death

Keep damage synchronous and `<transacts>`; return whether the entity died so the
caller can award score:

```verse
TakeDamage<public>(Damage : float)<transacts> : logic =
    if (not IsAlive?): return false
    set Health = Max(0.0, Health - Damage)
    if (Health <= 0.0):
        set IsAlive = false; DestroyProp()
        return true                            # died
    return false
```

### Spawner / wave manager

A manager holds the live entities in an array and runs a spawning loop. Add on
spawn, and rebuild the array to drop dead ones (same filter-rebuild idiom as maps):

```verse
var ActiveEnemies : []spawned_enemy_prop = array{}

SpawningLoop<private>()<suspends> : void =
    loop:
        if (not GameActive?): break
        SpawnOneWave()
        Sleep(WaveInterval)

# prune dead entities
var Living : []spawned_enemy_prop = array{}
for (E : ActiveEnemies, E.IsAlive?):
    set Living += array{E}
set ActiveEnemies = Living
```

Find the closest target by scanning the array with `Distance` and a running best
(track a `var ClosestDistance` / `var ?entity` and update as you loop).

### NPC spawning & elimination

For engine NPCs, subscribe to the spawner's events from the digest:

```verse
Spawner.SpawnedEvent.Subscribe(OnNPCSpawned)      # npc_spawner_device
# in the handler, subscribe the spawned character:
NpcFort.EliminatedEvent().Subscribe(OnNPCEliminated)
```

Track counts and trigger the next wave / reward when the count hits zero.

### Reliable player teleport (retry-until-success)

Teleport can fail if the destination is briefly blocked. Retry in an async loop
with a timeout, confirming arrival by distance:

```verse
TeleportPlayersUntilSuccessLoop<public>(Position : vector3)<suspends> : void =
    var TimeOut : int = 600
    loop:
        Sleep(0.1)
        set TimeOut -= 1
        if (TimeOut <= 0): break
        if:
            Char := MyAgent.GetFortCharacter[]
            Char.TeleportTo[Position, IdentityRotation()]
            Distance(Char.GetTransform().Translation, Position) <= 100.0
        then:
            break                              # confirmed arrival
```

`TeleportTo[...]` is failable (`[]`) — call it inside the `if:` head. Kick it off
with `spawn{ TeleportPlayersUntilSuccessLoop(Pos) }` from a sync method.

### Runtime prop spawn (PropSpawnManager) — not only pre-placed props

For delivery props created at runtime (confirm `SpawnProp` /
`Dispose` names in the digest):

```verse
# Hold input_trigger → ContinuousSpawnLoop (sys_input_devices)
SpawnAndDeliver(Agent : agent)<suspends> : void =
    if (not HasFreeStorage(Agent)?):
        return
    ReserveStorageSlot(Agent)
    if (Prop := SpawnProp[PropAsset, StartTransform]?):   # digest: exact API
        MoveAlongPath(Prop)                               # MoveTo / nav points
        if (GP := PlayerManager.GetGamePlayer(Agent)?):
            GP.Services.EconomyManager.AddCurrency("Coins", Payout)
        Prop.Dispose()                                    # or equivalent cleanup
```

| Step | Detail |
|------|--------|
| Gate | Building/storage capacity before spawn (`sys_buildings`) |
| Input | Pressed starts loop; Released stops (`sys_input_devices`) |
| Path | Nav points / smooth path samples + `MoveTo` |
| End | Grant currency, VFX optional, dispose prop |
| Unlock | Building unlock enables matching end-nav set |

Keep **pre-placed** `@editable creative_prop` movement in the sections above;
keep **NPC** waves via `npc_spawner_device`. Label your device clearly:
`prop_spawn_manager` vs NPC spawner.

### Gotchas

- Every spawn loop needs a stop condition and a `Sleep`/`Await` — see `async`.
- Mutating `creative_prop` transforms directly vs `MoveTo` (animated): pick per
  need; `MoveTo` is async and yields.
- Prune dead entities from your arrays/maps or they pile up across waves.
- Runtime props: always dispose or you leak actors.
- Confirm `MoveTo`, `TeleportTo`, `SpawnProp`, spawner events, and NPC APIs in
  the digest — don't guess the names.
