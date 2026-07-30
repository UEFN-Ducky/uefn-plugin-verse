---
description: "NPC AI in Verse — npc_behavior templates, nearest-player lookup, spread/strafe movement, centralized damage, Scene Graph projectiles, and wave spawn managers"
metadata:
  order: 40
  label: "Game systems — NPC AI (npc_behavior)"
  default_enabled: false
  load_condition: "Writing npc_behavior subclasses, enemy AI loops, melee/ranged combat, Scene Graph projectiles, or npc_spawner wave managers"
---

## NPC AI — `npc_behavior` patterns

Names below are **generic**. Confirm every API (`npc_behavior`, `GetNavigatable`,
`PlayAndAwait`, `npc_spawner_device`, Scene Graph types) in the digests before
writing. Pair this with the **animation** pack's `npc_characters` reference for
character definitions and AnimPresets — Verse owns behavior; content owns mesh/anim.

### Hard constraints (read first)

| Trap | Rule |
|------|------|
| `npc_behavior` calling `GetPlayspace()` | **Fails / unavailable.** Use `Behavior.GetEntity[]` → `GetPlayspaceForEntity[]` → `GetPlayers()`. |
| Module-scope mutable singletons for AI state | Illegal under `<transacts>` in many contexts. Prefer helpers that take the behavior instance, or a placed `creative_device` the behavior can reference. |
| Behaviors calling `fort_character.Damage` | **Never.** One shared helpers module owns damage (`ApplyHitDamage` / melee / AOE / projectile). Behaviors only call those helpers after a real hit. |
| `SpawnProp` walls vs SG projectile sweeps | `FindSweepHits` only sees **Scene Graph** colliders (`Queryable`). Creative props are invisible to SG queries — walls/cover must be SG entities if projectiles should block. |

---

## 1. Behavior skeleton

Every enemy type is a `class(npc_behavior)` with `@editable` tuning and an
`OnBegin` loop. Guard the interfaces once, then tick until the character dies:

```verse
melee_enemy_behavior<public> := class(npc_behavior):
    @editable AttackAnim:?animation_sequence = false
    @editable HitRange:float = 220.0
    @editable HitDamage:float = 18.0
    @editable HitCooldown:float = 1.3
    @editable MaxChaseRange:float = 7500.0
    @editable SpreadDist:float = 260.0
    @editable EnableSidestep:logic = false
    @editable SidestepChance:int = 35

    OnBegin<override>()<suspends>:void =
        if:
            Agent := GetAgent[]
            Char := Agent.GetFortCharacter[]
            Nav := Char.GetNavigatable[]
            Focus := Char.GetFocusInterface[]
            Anim := Char.GetPlayAnimationController[]
        then:
            loop:
                Sleep(0.1)
                if (not Char.IsActive[]):
                    break
                if (Target := FindNearestPlayer(Self, Char, MaxChaseRange)?):
                    # chase / attack — see sections below
                else:
                    Sleep(1.0)
```

**Interfaces you almost always need:**

- `GetNavigatable[]` → `NavigateTo(MakeNavigationTarget(...), ?MovementType := movement_types.Running, ?ReachRadius := …)`
- `GetFocusInterface[]` → `MaintainFocus(LookAtPoint)` (async — race it)
- `GetPlayAnimationController[]` → `PlayAndAwait(Clip)` for attack swings

Confirm exact member names in the digest — they evolve.

### Nearest-player helper (no wired manager required)

```verse
FindNearestPlayer<public>(Behavior:npc_behavior, FortChar:fort_character, DetectionRange:float)<transacts>:?fort_character =
    var Best:?fort_character = false
    var BestDist:float = DetectionRange
    if (Ent := Behavior.GetEntity[], PS := Ent.GetPlayspaceForEntity[]):
        SelfPos := FortChar.GetTransform().Translation
        for (Player : PS.GetPlayers(), PlayerChar := Player.GetFortCharacter[]):
            if:
                PlayerChar.IsActive[]
                not PlayerChar = FortChar
                D := Distance(SelfPos, PlayerChar.GetTransform().Translation)
                D < BestDist
            then:
                set Best = option{PlayerChar}
                set BestDist = D
    Best
```

Look-at for focus: aim at the **target position** — do not invent global yaw
hacks. If a mesh faces the wrong way, fix the character asset axis, not every
behavior's look offset.

---

## 2. Movement idioms — race focus + navigate

Chase and fight while facing the player. Cap each hop with `Sleep` so the loop
can re-target:

```verse
LookAt := TargetPos   # or a helper that returns TargetPos
race:
    Nav.NavigateTo(MakeNavigationTarget(Approach), ?MovementType := movement_types.Running, ?ReachRadius := 150.0)
    Focus.MaintainFocus(LookAt)
    Sleep(0.55)
```

### Spread ring (packs fan out instead of stacking)

Approach a ring around the player with a random side offset:

```verse
# PreferDist = desired stand-off; SideMin/SideMax = lateral scatter
SpreadApproachPoint(SelfPos, TargetPos, PreferDist, SideMin, SideMax):vector3 =
    Away := SelfPos - TargetPos
    # unit XY Away → RingDir; random side along lateral (-Away.Y, Away.X)
    # return TargetPos + RingDir * RingDist + Lat * Side
```

### Sidestep hop

Optional checkbox + percent chance: jump left/right while still facing the fight.
Gate with `EnableSidestep` then `GetRandomInt(1, 100) <= ChancePercent`.

---

## 3. Centralized damage (one helpers file)

**Behaviors must never call `Target.Damage`.** Put all hit application in one
module so print tags, VFX, and balance stay consistent:

```verse
ApplyHitDamage(Target:fort_character, Amount:float, Tag:string):void =
    if (Target.IsActive[]):
        Print("{Tag} dmg={Amount}")
        Target.Damage(Amount)

# Melee: only damage if STILL inside HitRange after the swing finishes
MeleeHit(Attacker:fort_character, Target:fort_character, HitRange:float, Amount:float):logic =
    Dist := Distance(Attacker.GetTransform().Translation, Target.GetTransform().Translation)
    if (Dist <= HitRange):
        ApplyHitDamage(Target, Amount, "MELEE HIT")
        return true
    false

# AOE: every active player within Radius of Center
AOEHit(Behavior:npc_behavior, Center:vector3, Radius:float, Amount:float):void =
    if (Ent := Behavior.GetEntity[], PS := Ent.GetPlayspaceForEntity[]):
        for (Player : PS.GetPlayers(), PChar := Player.GetFortCharacter[]):
            if (PChar.IsActive[], Distance(Center, PChar.GetTransform().Translation) <= Radius):
                ApplyHitDamage(PChar, Amount, "AOE HIT")
```

Melee attack block pattern:

```verse
race:
    Focus.MaintainFocus(LookAt)
    block:
        if (Clip := AttackAnim?):
            Anim.PlayAndAwait(Clip)
        MeleeHit(Char, Target, HitRange, HitDamage)
        Sleep(HitCooldown)
```

---

## 4. Scene Graph projectile (ranged)

Creative `SpawnProp` arrows do **not** collide with SG walls. Use an entity +
mesh component + keyframed motion:

1. Spawn `entity{}`, add `sphere` (or mesh) with `Collidable = true`, `Queryable = true`, `Visible = true`.
2. Add `keyframed_movement_component`, `Sim.AddEntities`, `SetGlobalTransform` at muzzle.
3. **Pre-sweep** walls: `FindSweepHits` along the flight path; clamp end position to first hit past a min clearance.
4. Build one `keyframed_movement_delta` (translation delta, duration = distance/speed, linear easing), `SetKeyframes` + `Play`.
5. Per-frame loop (`Sleep(0.0)`): read global transform; if within `HitRadius` of aim point → `ApplyHitDamage` and stop; optional shoot-down (player holding fire + aim ray near projectile); exit when keyframes finish.
6. Cleanup: cancel trail VFX handles, `RemoveFromParent()`.

```verse
# Pseudocode — confirm types in digests / scenegraph pack
ArrowEnt := entity{}
Mesh := sphere{Entity := ArrowEnt}
set Mesh.Collidable = true
set Mesh.Queryable = true
set Mesh.Visible = true
MoveComp := keyframed_movement_component{Entity := ArrowEnt}
ArrowEnt.AddComponents(array{Mesh, MoveComp})
Sim.AddEntities(array{ArrowEnt})
# SetGlobalTransform → FindSweepHits pre-sweep → SetKeyframes → Play → hit loop → RemoveFromParent
```

**Shoot-down trap:** Fortnite guns cannot damage SG spheres. Track "fire held"
via an `input_trigger_device` (see `sys_input_devices`) into a `weak_map(player, logic)`,
then each frame: if fire held AND aim ray within `ShootDownRadius` of the projectile → destroy + VFX.

**Walls:** dungeon / cover colliders must be Scene Graph entities with Queryable
collision, or every shot flies through.

---

## 5. Archetype variants (same skeleton, different params)

| Archetype | Prefer range | Attack |
|-----------|--------------|--------|
| Melee | close `HitRange` | anim + `MeleeHit` |
| Ranged / archer | keep `PreferMin`–`PreferMax`; back off if too close | anim + SG projectile |
| Charger | large chase; slam at `SlamRange` | optional wind-up `Sleep` then `MeleeHit` |
| Exploder | close then AOE | `AOEHit` at self / fuse point |

Reuse spread/strafe helpers; only ranges, damage, cooldown, and the attack call differ.

---

## 6. Wave spawn manager (`creative_device`)

Wire one `npc_spawner_device` per character definition (see animation
`npc_characters`). The manager counts alive and spawns waves:

```verse
enemy_spawn_manager := class(creative_device):
    @editable SpawnerA:?npc_spawner_device = false
    # … more optional spawners …
    @editable SpawnInterval:float = 8.0
    @editable MaxAlive:int = 40
    @editable SeedWaveOnStart:logic = true
    @editable AutoSpawn:logic = true
    var AliveCount:int = 0

    OnBegin<override>()<suspends>:void =
        # Subscribe SpawnedEvent / EliminatedEvent on every wired spawner
        # AliveCount += 1 on spawn; Max(0, AliveCount - 1) on eliminate
        if (SeedWaveOnStart?):
            SpawnAllTypes()
        if (AutoSpawn?):
            loop:
                Sleep(SpawnInterval)
                if (AliveCount < MaxAlive):
                    SpawnAllTypes()

    TrySpawn(Maybe:?npc_spawner_device):void =
        if (AliveCount < MaxAlive, S := Maybe?):
            S.Spawn()
```

Confirm event / `Spawn()` signatures in the digest. Each spawner in the level
points at one `NPCCharacterDefinition` asset.

---

## Checklist — new enemy type

1. Content: mesh + restored anims + AnimPreset + `NPCCharacterDefinition` with `CharacterModifier_VerseBehavior` → this behavior class (`npc_characters`).
2. Verse: new `npc_behavior` subclass (or reuse an archetype with different `@editable` defaults).
3. Assign attack anim / props on the definition's Verse Behavior modifier slots.
4. Place `npc_spawner_device` → wire into spawn manager.
5. `workspace_list_verse_errors` → fix until clean.
6. PIE: confirm chase, hit prints (`MELEE HIT` / projectile tags), and elimination counting.

**MetaHuman enemies:** assemble with UEFN Export and finish mesh / physics /
AnimPreset / spawn wiring via `skill_read_subskill("metahuman", "npc_spawn")`
*before* writing `npc_behavior` — Verse owns the AI loop; the metahuman pack
owns Creator → assemble → definition.

Cross-links: `sys_spawning` (prop pools / teleport), `sys_input_devices` (shoot-down fire held), `async` (`race` / `Sleep`), `devices` (`@editable` / `OnBegin`), metahuman `npc_spawn`.
