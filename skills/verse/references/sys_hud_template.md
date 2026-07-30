---
description: "Any-manager display template — *_canvas_builder, ShowHUD/RemoveHud, shop rows, inventory slots, progress bars; driven by any Services manager"
metadata:
  order: 34
  label: "Game systems — any manager canvas display (HUD / shop / inventory)"
  default_enabled: false
  load_condition: "Creating per-player on-screen UI for any manager — wallet, XP, shop rows, inventory slots, tabs, progress bars — canvas_builder and ShowHUD"
---

## Any-manager canvas display template

This is the **display half** of any player feature — wallet, XP, shop HUD,
inventory bag, whatever. Pair with `sys_architecture` (wiring), `ui` (primitives),
and **`sys_canvas_cookbook`** (compositions + visibility checklist). Names are
generic.

### The split (do not put layout in the manager)

| Piece | File / type | Owns |
|-------|-------------|------|
| Manager | `your_manager` (`class<unique>`) | leaf widgets, data sync, `ShowHUD` / `RemoveHud` |
| Builder | `your_hud_canvas_builder` (`class`) | **layout only** — `SetUIElements` + `CreateCanvas` |
| Device | `your_manager_device` | pushes config on connect, then calls `ShowHUD` |

The manager creates and keeps the leaf instances so it can mutate them later.
The builder **never** creates replacement text blocks for values you need to
update — it only places the leaves you passed in.

Layouts (panel, rows, grids, bars, modals): copy from **`sys_canvas_cookbook`**.

### Imports

```verse
using { /Fortnite.com/UI }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Colors }
```

```verse
Message<localizes>(String : string) : message = "{String}"
```

### 1. Manager owns leaves + canvas handle

```verse
your_manager := class<unique>():
    Message<localizes>(String : string) : message = "{String}"
    var MyAgent : ?agent = false
    var HudCanvas : canvas = canvas{}
    var HudAdded : logic = false
    var CanvasBuilder : your_hud_canvas_builder = your_hud_canvas_builder{}
    # LEAVES — one of each you will mutate (or [] arrays for lists/grids)
    var TitleText : text_block = text_block{}
    var ValueText : text_block = text_block{}
    var IconBlock : texture_block = texture_block{
        DefaultImage := Textures.T_Empty
        DefaultDesiredSize := vector2{X := 60.0, Y := 60.0}
    }
    var BarBackground : color_block = color_block{ DefaultDesiredSize := vector2{X := 300.0, Y := 15.0} }
    var BarFill : color_block = color_block{ DefaultDesiredSize := vector2{X := 0.0, Y := 15.0} }
```

### 2. Builder — SetUIElements + CreateCanvas

Pass manager leaves in; assemble using cookbook compositions (corner HUD, panel,
progress bar). Full-screen root anchors `0→1`, then place with overlay alignment
+ padding. See `sys_canvas_cookbook` for trees.

### 3. ShowHUD / RemoveHud

```verse
ShowHUD<public>(Agent : agent) : void =
    if (HudAdded?):
        return
    set MyAgent = option{Agent}
    if (Player := player[MyAgent?], PlayerUI := GetPlayerUI[Player]):
        CanvasBuilder.SetUIElements(…)
        set HudCanvas = CanvasBuilder.CreateCanvas()
        PlayerUI.AddWidget(HudCanvas, player_ui_slot{ InputMode := ui_input_mode.None })
        set HudAdded = true
        SyncFromData()

RemoveHud<public>() : void =
    if (Player := player[MyAgent?], PlayerUI := GetPlayerUI[Player]):
        PlayerUI.RemoveWidget(HudCanvas)
        set HudCanvas = canvas{}
        set HudAdded = false
```

Use `ui_input_mode.All` when the canvas has buy/slot buttons (`sys_ui_menus`).

### 4. Live updates — mutate leaves

```verse
SyncFromData() : void =
    ValueText.SetText(Message("{Pct}%"))
    IconBlock.SetImage(CurrentIcon)
    BarFill.SetDesiredSize(vector2{ X := (Pct / 100.0) * 300.0, Y := 15.0 })
```

Rebuild only when **row/slot count** changes.

### Shop rows (EconomyManager)

Leaves per offer: `ItemIcon`, `NameText`, `PriceText`, optional `BuyButton`.
Layout: cookbook **vertical list of shop lines** inside a **panel**. Show with
`.All`. On click:

```verse
if (GP := PlayerManager.GetGamePlayer(Agent)?):
    if (GP.Services.EconomyManager.GetCurrency(CurrencyName) >= Price):
        GP.Services.EconomyManager.RemoveCurrency(CurrencyName, Price)
        ItemGranter.GrantItem(Agent)
        SyncShopUI()
```

### Inventory slots (InventoryManager)

Leaves: `[]texture_block` icons + `[]text_block` quantities (cookbook **item slot
grid** or list). After `AddItem` / `RemoveItem` call `UpdateInventoryUI()` that
only `SetText` / `SetImage`s. Passive bag HUD → `.None`; clickable slots → `.All`.

### Tabs

Cookbook **tab header + content**: horizontal `button_loud`s + one content region.
Swap content on click; keep `.All`.

### Checklist

1. Leaf `var`s on `<unique>` manager (or device controller).
2. `*_canvas_builder` with `SetUIElements` + `CreateCanvas`.
3. Visibility checklist in `sys_canvas_cookbook`.
4. `ShowHUD` → sync; every mutation ends with leaf updates.
5. Device: config → init → `ShowHUD` (`sys_architecture`).

### Gotchas

- Pass the manager’s leaf instances into the builder — not the builder’s defaults.
- Wrong slot type → compile error (`ui`).
- Raw `string` into `SetText` → use `Message`.
- Confirm widget APIs with `search_verse_digest`.
