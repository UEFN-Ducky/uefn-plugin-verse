---
description: "Building unlock & reveal — paid upgrades via economy, underground Z-teleport prop swap, Hide/Show alternative, nav coupling for delivery paths"
metadata:
  order: 39
  label: "Game systems — building unlock & plot reveal (BuildingUnlockManager)"
  default_enabled: false
  load_condition: "Unlocking or upgrading buildings/plots, teleporting props to reveal tiers, coupling unlocks to delivery nav paths"
---

## Building unlock & reveal — BuildingUnlockManager

Tycoon-style plots: pay with `economy_manager`, swap visible prop tiers, optional
hook into delivery spawners. Names are generic. Generators/rates: `sys_generators`.

### Unlock / upgrade flow

```verse
UnlockOrUpgrade(Agent : agent, BuildingIndex : int) : void =
    if (GP := PlayerManager.GetGamePlayer(Agent)?):
        Cost := CostFor(BuildingIndex, NextLevel)
        if (GP.Services.EconomyManager.GetCurrency(CurrencyName) >= Cost):
            GP.Services.EconomyManager.RemoveCurrency(CurrencyName, Cost)
            set PlayerBuildingLevel[Agent][BuildingIndex] = NextLevel
            ApplyReveal(BuildingIndex, NextLevel)
            NotifyDeliveryUnlock(BuildingIndex)   # optional nav hook
```

Persist levels in `game_player_table` if they must survive sessions; otherwise
session maps are fine (document the choice).

### Underground Z-teleport reveal (preferred for multi-tier props)

1. At `OnBegin`, cache each tier prop’s original transform.
2. Park inactive tiers at `Translation.Z + UndergroundOffset` (e.g. -5000).
3. On unlock/upgrade: teleport the **active** tier to the level-0 anchor; park
   siblings underground again.

No `Hide`/`Show` required — props stay loaded, just moved. Shared worlds often
drive **visual** tier from max level across players while **progress** stays
per-agent.

### Simple Hide/Show reveal

For a single one-off prop: trigger → `Prop.Show()` / `Hide()`. Use when there is
no tier ladder. Do not mix both patterns on the same prop without a clear reason.

### Online earn vs unlock

- Unlock spends currency once.
- Passive income may come from a storage→tick loop (`sys_generators`) filled by a
  `prop_spawn_manager` delivery path (`sys_spawning`).

### Nav / delivery coupling

When building index N unlocks, enable end-nav set N so delivered props can finish
at that building. Filter ends by storage fullness if capacity-gated.

### UI

Status / buy buttons: `sys_canvas_cookbook` + `sys_ui_menus` or passive HUD via
`sys_hud_template`.

### Gotchas

- Cache origins before the first park underground or you lose the anchor.
- Teleport reveal ≠ material swap; pick one visual strategy.
- Confirm `TeleportTo` / prop APIs in the digest.
