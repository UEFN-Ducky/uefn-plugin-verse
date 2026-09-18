---
description: "Full plot tycoon — tycoon_controller, plot_manager, purchaseable types, rebirth, persist nest on player_core"
metadata:
  order: 38
  label: "Game systems — tycoon plots & purchaseables"
  default_enabled: false
  load_condition: "Building a tycoon / idle plot — claim pads, purchaseables, droppers, conveyors, pets, rebirth"
---

## Tycoon — plots that consume island packs

**Consume, don't own (HARD):** apply `player_core` → `economy` → `progression` →
`time_tracker` → `tycoon`. Wire `@editable PlayerManager` on `tycoon_controller`
and each `plot_manager`. Pay with `GetCurrencyProvider()`, XP with
`GetXPAwarder()`, offline with `GetPlaytimeProvider()`. Never put a wallet,
XP table, or persist `weak_map` in `Verse/Tycoon/` (a fifth map is error 3502).

Progress nests on Player Core `game_player_table`: `PlotRebirths`, `PlotUnlocks`,
`PlotLevels` (defaulted fields). Helpers: `PackPlotUnlock` / `AddPlotUnlock` /
`AddPlotRebirth` / `GetPlotLevel`.

```
tycoon_controller  →  []plot_manager
plot_manager       →  typed []purchaseable arrays + runtime collectables/gifts/wheels
purchaseable       →  TryBuy → RemoveCurrency → AddPlotUnlock → Activate()
```

Claim modes on the controller: `Manual` (plot ClaimButton), `Fill` (first free
plot on join), `Teleport` (Fill + `ClaimTeleporter.Teleport`).

### Add a purchaseable type

1. New file under `Verse/Tycoon/` subclassing `purchaseable`.
2. Override `Activate()<suspends>` for post-buy behavior (call `StartGrantLoop()`
   if you still want interval grants).
3. Add `@editable MyThings : []my_thing_purchaseable` on `plot_manager`.
4. `Initialize(Self, TypeIndex, I)` in `InitializeAll` and a branch in
   `FindPurchaseable`.

```verse
my_thing_purchaseable <public> := class<concrete>(purchaseable):
    Activate<override>()<suspends> : void =
        ShowRevealProps()
        StartGrantLoop()
```

Type indices in the shipped pack: 0 prop, 1 generator, 2 dropper, 3 conveyor,
4 upgrader, 5 npc, 6 pet, 7 dancefloor, 8 hitable, 9 shootable.

Dependents: `@editable Dependents : []plot_link` (TypeIndex + ItemIndex). Buy
unlocks those rows. `StartsLocked := true` until a parent buys.

### Rebirth

`plot_manager` RebirthButton: charge `RebirthCost * multiplier^rebirths` through
Economy, drain known currency indices, `AddPlotRebirth` (clears unlocks/levels),
`OnRebirth` on every purchaseable. Later `GrantToAgent` scales by
`GrantMultiplier ^ PlotRebirths`.

### Belt

Droppers `Activate` call `FindConveyor(ConveyorIndex).LinkDropper`. Upgraders
multiply `plot_manager.BeltMultiplier`. Use Creative devices / props — no custom
physics classes. Audio = `audio_player_device` only.

### Runtime (not purchaseables)

`plot_collectable`, `timed_gift`, `money_wheel` init on claim via `ShowRuntime`.
They grant through `GrantToAgent` (same rebirth scale).

HUD: Economy owns the wallet canvas. Plot feedback is `hud_message_device` on
the purchaseable / plot. Prop reveal is underground `TeleportTo` (see
`sys_buildings`). Generators: `sys_generators`.
