---
description: "Idle / tycoon systems — passive resource generators, upgrade tiers, collect-on-tick loops, and offline/away earnings from elapsed time"
metadata:
  order: 29
  label: "Game systems — generators, upgrades & idle income"
  default_enabled: false
  load_condition: "Building tycoon/idle mechanics — passive income generators, buildings/upgrades with tiers, or offline earnings"
---

## Generators, upgrades & idle income

Tycoon/idle games are **producers that pay out over time**, plus **upgrade tiers**
that raise the rate. All names below are generic. Pair with `sys_economy` for the
wallet and `persistence` for saving progress.

### A generator (producer)

Model each producer with its rate, level, and cost curve. Keep it `<concrete>` so
it can be an `@editable` array element:

```verse
generator_tier := class<concrete>():
    @editable RatePerSecond : float = 1.0
    @editable UpgradeCost : int = 100

generator := class<unique>():
    @editable Prop : creative_prop = creative_prop{}
    @editable Tiers : []generator_tier = array{}
    var Level <private> : int = 0
    var Accrued <private> : float = 0.0        # earned but not yet collected

    CurrentRate<public>()<transacts> : float =
        if (Tier := Tiers[Level]): Tier.RatePerSecond else: 0.0
```

### The generation loop

Accrue by **real elapsed time** (delta), not per-frame, so the payout is
frame-rate independent. Spawn one loop per generator (or one loop that walks all
generators):

```verse
StartGeneration<public>() : void =
    spawn{ GenerationLoop() }

GenerationLoop<private>()<suspends> : void =
    var LastTime : float = GetSimulationElapsedTime()
    loop:
        Sleep(0.25)                                  # tick a few times a second
        Now := GetSimulationElapsedTime()
        Delta := Now - LastTime
        set LastTime = Now
        set Accrued += CurrentRate() * Delta         # rate × seconds
        UpdateHUD()
```

Collect the accrued amount into the wallet on interact (or automatically), then
reset:

```verse
Collect<public>(Agent : agent) : void =
    if (Whole := Floor[Accrued]):
        EconomyManager.AddCurrency("Coins", Whole)
        set Accrued -= (Whole * 1.0)
```

### Upgrades / buy & build

An upgrade is: check funds → charge → bump level → refresh visuals. Guard the tier
lookup so you can't exceed the top tier:

```verse
Upgrade<public>(Agent : agent) : void =
    NextLevel := Level + 1
    if (NextTier := Tiers[NextLevel], EconomyManager.GetCurrency("Coins") >= NextTier.UpgradeCost):
        EconomyManager.RemoveCurrency("Coins", NextTier.UpgradeCost)
        set Level = NextLevel
        RefreshBuildingVisual()                      # swap mesh/material for the tier
```

For "buy the next building", keep an array of build states and unlock the next
index; `spawn` the new building's generation loop when it unlocks.

### Offline / away earnings (OfflineRewardService orchestration)

**Ordered recipe — do not reorder:**

1. `player_time_tracker.InitializeTimeTracking` runs on connect (creates session;
   **does not** overwrite `LastLoginTime` for returning players — see
   `sys_time_tracking`).
2. Offline device reads `TimeTracker.GetLastLoginTime()`.
3. `Elapsed = clamp(now - lastLogin, 0, MaxOfflineSeconds)` (hours or seconds
   consistently).
4. `Earnings = rate × elapsed` (sum per unlocked idle station/generator if many).
5. Show collect modal (`sys_ui_menus`) **or** auto-grant — if modal, grant only
   on Confirm click via `EconomyManager.AddCurrency`.
6. **Then** stamp `SetLastLoginTime(now)` / persist last-seen.

```verse
ProcessOfflineOnJoin(GP : game_player) : void =
    Now := GetSecondsSinceEpoch()
    Last := GP.Services.TimeTracker.GetLastLoginTime()
    ElapsedRaw := Now - Last
    Elapsed := Min(Max(0.0, ElapsedRaw), MaxOfflineSeconds)
    if (Whole := Floor[RatePerSecond * Elapsed]):
        if (Whole > 0):
            OfflinePopup.ShowCollect(GP.GetAgent(), Whole)  # grants on click
    # stamp AFTER calc (and after popup show is OK; grant uses stored Whole)
    GP.Services.TimeTracker.TimeSaveService.SetLastLoginTime(option{GP.GetAgent()}, Now)
```

| Clock | Use |
|-------|-----|
| `GetSimulationElapsedTime()` | In-session generator ticks only |
| Epoch seconds | Offline / away across sessions |

**Dual earn paths (do not conflate):**

- **Online:** storage filled by prop delivery → tick converts storage → wallet
  (`sys_buildings` / `sys_spawning`).
- **Offline:** real elapsed time → idle station rate → wallet (this section).

Both write through `EconomyManager`. Subscription order: time tracker and offline
device both listen to player-connected — offline math must see initialized
TimeTracker (same event bus; ensure time device is ready or call init first).

### Rules

- Store the **raw** number for math; only format (K/M/B) for the HUD (see
  `sys_economy`).
- Accrue with delta time; never assume `Sleep` is exact.
- **Cap offline earnings** and validate elapsed time is positive.
- **Never stamp LastLoginTime before offline payout math.**
- Save `Level` + timestamps (and accrued, if you don't force a collect on quit).
- One `spawn`ed loop per generator, each with a `Sleep` — see `async`.
