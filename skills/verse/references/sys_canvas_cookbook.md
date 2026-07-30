---
description: "Universal Verse canvas cookbook — invent any on-screen UI (shop, inventory, HUD, modal, grid) that shows visually; compositions, visibility checklist, drive from any Services manager"
metadata:
  order: 35
  label: "UI — invent any canvas (shops, inventory, HUD, menus)"
  default_enabled: false
  load_condition: "Creating any Verse canvas UI — shop, inventory, HUD, modal menu, tabbed panel, item grid, progress bar, or dynamic cell board that must show on screen"
---

## Canvas cookbook — invent any UI that shows

Use this when building **any** on-screen Verse UI from skills alone — shops,
inventory, wallets, XP, collect popups, tabs, minigame boards. Pair with
`ui` (primitives), `sys_hud_template` (manager + builder + ShowHUD), and
`sys_ui_menus` (interactive `.All`). Names are generic.

### Universal recipe (never skip steps)

```
1. Manager (class<unique>) owns leaf widgets as var fields
2. *_canvas_builder.SetUIElements(leaves) then CreateCanvas()  # layout only
3. if (Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
       PlayerUI.AddWidget(Canvas, player_ui_slot{ InputMode := … })
4. After every data change: mutate leaves (SetText / SetImage / SetDesiredSize)
5. Hide: PlayerUI.RemoveWidget(Canvas)
```

| Mode | Use |
|------|-----|
| `ui_input_mode.None` | Passive HUD, overlay board (input from Creative devices) |
| `ui_input_mode.All` | Shop / inventory / collect popups that need clicks |

### Visibility checklist (if it does not show, check these)

1. Leaves are the **same instances** the builder places (pass via `SetUIElements`)
2. `GetPlayerUI[Player]` succeeded (guard in `if`)
3. `AddWidget` was called with a `player_ui_slot`
4. Every visual leaf has **non-zero** `DefaultDesiredSize` (e.g. `60.0`, not `0.0`)
5. Text uses `Message<localizes>(…)` / `SetText(Message(…))` — not a raw `string`
6. Root `canvas_slot` has full-screen anchors `0→1`, then place content with
   overlay alignment + `Padding` (or sub-anchors)
7. Floats everywhere (`400.0`, not `400`)
8. Slot types match containers (`canvas_slot` / `overlay_slot` / `stack_box_slot`)

### Drive from any Service

After economy / inventory / progression changes:

```verse
if (GP := Manager.GetGamePlayer(Agent)?):
    GP.Services.EconomyManager.AddCurrency("Coins", 10)
    GP.Services.EconomyManager.UpdateWalletUI()   # mutates leaves
# shop device owns its own canvas — call its SyncShopUI() the same way
```

Same pattern for `InventoryManager`, `ProgressionManager`, or a shop
`ui_menu_controller` on a device.

### Mutate vs rebuild

| Situation | Action |
|-----------|--------|
| Number / icon / bar width changed | Mutate leaf (`SetText`, `SetImage`, `SetDesiredSize`) |
| Row/slot count changed | Rebuild list section or whole canvas, then `AddWidget` again |
| Minigame / dynamic cells | `AddWidget` / `RemoveWidget` individual cells on the live canvas |

---

## Composition catalog

All trees sit inside a full-screen root:

```verse
canvas_slot:
    Anchors := anchors:
        Minimum := vector2{X := 0.0, Y := 0.0}
        Maximum := vector2{X := 1.0, Y := 1.0}
    Widget := overlay:   # or stack_box — place children here
        Slots := array:
            …
```

### A. Corner / edge HUD cluster

```verse
overlay_slot:
    HorizontalAlignment := horizontal_alignment.Right
    VerticalAlignment := vertical_alignment.Bottom
    Padding := margin{ Bottom := 50.0, Right := 20.0 }
    Widget := stack_box:
        Orientation := orientation.Vertical
        Slots := array:   # one stack_box_slot per currency/stat row
            …
```

### B. Panel (background + content)

```verse
overlay:
    Slots := array:
        overlay_slot:
            HorizontalAlignment := horizontal_alignment.Fill
            VerticalAlignment := vertical_alignment.Fill
            Widget := PanelBackground   # texture_block or color_block with size
        overlay_slot:
            HorizontalAlignment := horizontal_alignment.Fill
            VerticalAlignment := vertical_alignment.Fill
            Widget := stack_box:        # title, rows, buttons
                Orientation := orientation.Vertical
                Slots := array:
                    …
```

### C. Horizontal currency / stat row (wallet-style)

```verse
stack_box:
    Orientation := orientation.Horizontal
    Slots := array:
        stack_box_slot:
            Widget := IconBlock
            Padding := margin{ Right := 5.0 }
        stack_box_slot:
            Widget := AmountText
```

Loop configs → build one row widget per currency → vertical `stack_box` of rows.

### D. Vertical list of shop / inventory lines

Each row = horizontal `stack_box`: icon + name + price/qty + optional `button_loud`.

```verse
stack_box_slot:
    Widget := stack_box:
        Orientation := orientation.Horizontal
        Slots := array:
            stack_box_slot{ Widget := ItemIcon }
            stack_box_slot{ Widget := ItemNameText }
            stack_box_slot{ Widget := PriceText }
            stack_box_slot{ Widget := BuyButton }   # interactive only if InputMode.All
```

### E. Item slot grid (rows × columns)

Nested loops: outer vertical `stack_box` of rows; each row a horizontal
`stack_box` of cell overlays (icon + qty text). Store leaf arrays
`[]texture_block` / `[]text_block` indexed like the grid so sync can update one slot.

### F. Progress bar

```verse
overlay:
    Slots := array:
        overlay_slot:
            HorizontalAlignment := horizontal_alignment.Fill
            Widget := BarBackground    # color_block full max width
        overlay_slot:
            HorizontalAlignment := horizontal_alignment.Left
            Widget := BarFill          # color_block; SetDesiredSize X by percent
```

`BarFill.SetDesiredSize(vector2{ X := (Pct / 100.0) * MaxWidth, Y := 15.0 })`

### G. Tab header + content

Horizontal `stack_box` of tab `button_loud`s; one content `overlay` below.
On tab click: hide/show content stacks or swap text/rebuild content children.
Keep `InputMode := .All`.

### H. Modal (dim + centered panel)

```verse
overlay:
    Slots := array:
        overlay_slot:   # full dim
            HorizontalAlignment := horizontal_alignment.Fill
            VerticalAlignment := vertical_alignment.Fill
            Widget := DimBlock   # color_block dark, large size
        overlay_slot:   # center panel
            HorizontalAlignment := horizontal_alignment.Center
            VerticalAlignment := vertical_alignment.Center
            Widget := PanelOverlay   # title + body + Confirm/Cancel buttons
```

`AddWidget(..., player_ui_slot{ InputMode := ui_input_mode.All })`. Full open/close
in `sys_ui_menus`.

### I. Dynamic cell board (minigame / live grid)

1. Create empty `canvas`, `AddWidget` once with `.None` (or `.All` if needed).
2. For each cell: `MyCanvas.AddWidget(canvas_slot{ Anchors := CellAnchors, Widget := color_block{…} })`.
3. On change: `RemoveWidget` old cell widgets, add new ones — or mutate
   `SetColor` / size if the digest supports it on your leaf type.
4. Map grid (Col, Row) → normalized `anchors` rects inside a board region.

Details in `sys_minigame_overlay`.

---

## Shop canvas (driven by EconomyManager)

Leaves on a shop device or `ui_menu_controller`: title text, per-offer icon/name/price
texts, buy buttons. Builder lays vertical list (composition D) inside a panel (B).
Show with `.All`. On buy click:

```verse
if (GP := PlayerManager.GetGamePlayer(Agent)?):
    if (GP.Services.EconomyManager.HasCurrency(Name, Price)?):  # or GetCurrency >=
        GP.Services.EconomyManager.RemoveCurrency(Name, Price)
        ItemGranter.GrantItem(Agent)
        SyncShopUI()
```

Confirm `HasCurrency` / button click payload names in the digest.

## Inventory canvas (driven by InventoryManager)

Leaves: slot icons + quantity texts (grid E or list D). Show with `.None` for
passive bag HUD, or `.All` if slots are clickable. After `AddItem` / `RemoveItem`:

```verse
GP.Services.InventoryManager.UpdateInventoryUI()  # SetText qty, SetImage icons
```

## Localized text

```verse
Message<localizes>(String : string) : message = "{String}"
TitleText.SetText(Message("SHOP"))
QtyText.SetText(Message("{Count}"))
```

## File split

```
your_feature/
  your_manager.verse          # owns leaves + Show/Sync
  your_feature_canvas.verse   # *_canvas_builder only
```

## Related skills

- Primitives / slot rules → `ui`
- Manager ShowHUD recipe → `sys_hud_template`
- Modals / buttons → `sys_ui_menus`
- Keybinds without UI capture → `sys_input_devices`
- Overlay / grid minigame → `sys_minigame_overlay`
