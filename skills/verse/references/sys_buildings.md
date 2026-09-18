---
description: "Building unlock & reveal — prop_purchaseable on a plot, underground Z-teleport, Hide/Show alternative"
metadata:
  order: 39
  label: "Game systems — building unlock & plot reveal"
  default_enabled: false
  load_condition: "Unlocking or upgrading buildings/plots, teleporting props to reveal tiers, coupling unlocks to delivery paths"
---

## Building unlock & reveal — `prop_purchaseable`

Tycoon plots: `verse_template_apply("tycoon")` then customize
`prop_purchaseable` on `plot_manager.Props`. Pay with
`PlayerManager.GetCurrencyProvider()` (the island `economy` pack — never a
tycoon-local wallet). Full kit map: `sys_tycoon`. Generators: `sys_generators`.

### Unlock flow

`purchaseable.TryBuy` charges `Price` / `CurrencyIndex`, writes `PlotUnlocks`,
then `ShowRevealProps()` (underground teleport back to cached anchors). Locked
rows wait on `Dependents` from a parent buy.

```verse
# After buy (already charged in purchaseable.FinishBuy):
Activate<override>()<suspends> : void =
    ShowRevealProps()
    StartGrantLoop()
```

Persist owned keys in `game_player_table.PlotUnlocks` via `AddPlotUnlock`.
Rejoin: `plot_manager.ApplySavedUnlocks`.

### Underground Z-teleport reveal (default in the pack)

1. `Initialize` caches each `RevealProps` transform, then parks at
   `Translation.Z + UndergroundOffset`.
2. On buy / loaded unlock: teleport each prop back to its anchor.
3. `OnRebirth` parks again.

No `Hide`/`Show` required — props stay loaded, just moved.

### Simple Hide/Show reveal

For a one-off prop you can `Prop.Show()` / `Hide()` instead of teleport. Do not
mix both patterns on the same prop without a clear reason.

### Nav / delivery coupling

When plot index N unlocks, enable end-nav set N so delivered props can finish
at that building (`sys_spawning`). Filter ends by storage fullness if
capacity-gated.

### UI

Plot feedback: `hud_message_device` on the purchaseable. Wallet HUD stays in
Economy (`sys_hud_template` / `sys_canvas_cookbook` for custom canvases).

### Gotchas

- Cache origins before the first park underground or you lose the anchor.
- Teleport reveal ≠ material swap; pick one visual strategy.
- Never own currency in `Verse/Tycoon/`.
