---
description: "Per-player inventory — persistable item entry arrays, immutable add/remove, quantity checks, re-granting physical items on load, and per-entry persist vs reset flags"
metadata:
  order: 33
  label: "Game systems — inventory & owned items"
  default_enabled: false
  load_condition: "Building a per-player item inventory, owned-collection, stackable items, re-granting items on join, or persist vs session-reset item flags"
---

## Inventory & owned items

A per-player inventory is a **named collection of stackable entries** in the
shared persistable table, plus a runtime manager and a placed device that
hooks the **player-manager connected bus** — same programming flow as wallet /
level (`sys_architecture`, `sys_player_data`, `sys_economy`). Names are generic.

**Player custom firearms** (Armory Entity Prefabs, `fort_trace_weapon_component`,
Verse grant/equip/clear) → `skill_read_subskill("scenegraph", "custom_weapons")`.
**Custom non-weapon Scene Graph items** (Entity Prefab pickup / icon / mesh) →
`skill_read_subskill("scenegraph", "custom_items")`. This file is soft persist
bags + Creative Item Granter re-grants — not Scene Graph Armory weapons or
custom item prefabs.

### Layers (same five-part shape)

```
persistable inventory_entry + player_inventory  → nested in shared table
inventory_save_service                   → rebuild-and-store
inventory_manager (class<unique>)         → field on game_player_services
inventory_manager_device                  → SubscribePlayerConnected + InitializeAll
```

### Persistable shapes

```verse
inventory_entry := class<final><persistable>:
    ItemId <public> : string = ""
    Quantity <public> : int = 0

player_inventory := class<final><persistable>:
    Entries <public> : []inventory_entry = array{}
```

Designer config (`class<concrete>`, not persisted):

```verse
item_config := class<concrete>():
    @editable ItemId <public> : string = ""
    @editable DisplayName : string = ""
    @editable Persistable : logic = true          # false → reset to 0 on join
    @editable ItemIcon : ?texture = false
    @editable ItemGranter : item_granter_device = item_granter_device{}
    @editable GranterSlotIndex : int = 0
```

### Immutable add / remove (persistence manager)

Same guard and rebuild pattern as currency:

```verse
AddItem(Agent : ?agent, ItemId : string, Amount : int) : void =
    if:
        RealAgent := Agent?
        Player := player[RealAgent]
        Player.IsActive[]
        OldTable := PlayerStatsMap[Player]
    then:
        var Updated : []inventory_entry = array{}
        var Found : logic = false
        for (Entry : OldTable.PlayerInventory.Entries):
            if (Entry.ItemId = ItemId):
                set Found = true
                set Updated += array{inventory_entry{
                    ItemId := ItemId
                    Quantity := Entry.Quantity + Amount
                }}
            else:
                set Updated += array{Entry}
        if (Found = false):
            set Updated += array{inventory_entry{ ItemId := ItemId, Quantity := Amount }}
        NewInv := player_inventory{ Entries := Updated }
        if (set PlayerStatsMap[Player] = UpdateInventory(OldTable, NewInv)):
            {}
```

`UpdateInventory` must copy **every** other nested field on the shared table.
Remove: subtract; drop the entry at zero (or clamp). Always guard `set` in `if`.

### Quantity checks (on the manager)

```verse
GetQuantity(ItemId : string)<transacts> : int =
    # walk Entries; return matching Quantity or 0

HasItem(ItemId : string, Amount : int)<transacts> : logic =
    CurrentAmount := GetQuantity(ItemId)
    if (CurrentAmount >= Amount):
        return true
    else:
        return false
```

Call `HasItem` before `RemoveItem`. Never trust the caller.

### Persist vs reset on join

After config is pushed, walk saved entries against config:

- **Persistable = true** — keep quantity; re-grant physical items if needed
- **Persistable = false** — write quantity `0`
- **Unknown id** — leave unchanged or drop (pick one policy)

### Re-granting physical items

Verse persistence does not restore Fortnite backpack items. Drive
`item_granter_device` from the digest on load / add. Removal typically uses
`conditional_button_device` (confirm members with `search_verse_digest`).

```verse
GrantItemsForEntry(Config : item_config, Agent : agent, Amount : int) : void =
    if (Amount <= 0):
        return
    Config.ItemGranter.SetNextItem(Config.GranterSlotIndex)
    for (I := 1..Amount):
        Config.ItemGranter.GrantItem(Agent)
```

### Placed device wiring (exact pattern — mirror wallet/level)

```verse
inventory_manager_device := class(creative_device):
    @editable PlayerManager : player_manager = player_manager{}
    @editable ItemConfigs : []item_config = array{}

    OnBegin<override>()<suspends> : void =
        PlayerManager.SubscribePlayerConnected(OnPlayerJoined)
        InitializeAllPlayerInventories()

    InitializeAllPlayerInventories() : void =
        Agents := Self.GetPlayspace().GetPlayers()
        for (Agent : Agents):
            if (CPlayer := PlayerManager.GetGamePlayer(Agent)?):
                OnPlayerJoined(CPlayer)
            # else: wait for PlayerConnected bus

    OnPlayerJoined(GamePlayer : game_player) : void =
        # 1) config first  2) persist init / re-grant  3) HUD
        GamePlayer.Services.InventoryManager.SetItemConfigs(ItemConfigs)
        GamePlayer.Services.InventoryManager.InitializeInventoryState(
            option{GamePlayer.MyAgent},
            ItemConfigs
        )
        GamePlayer.Services.InventoryManager.ShowHUD(GamePlayer.MyAgent)
```

**Order is mandatory:** `SetItemConfigs` → `InitializeInventoryState` → `ShowHUD`.
Reversing grants against an empty config list.

**HUD guard:** `var HudAdded : logic = false` so Subscribe + InitializeAll do not
stack two canvases.

### Runtime manager

`inventory_manager := class<unique>():` — holds `MyAgent`, config array,
optional canvas, persistence manager. Public API: `AddItem`, `RemoveItem`,
`GetQuantity`, `HasItem`, `ShowHUD` / `RemoveHud`. Add the field on
`game_player_services` so it exists before any device's `OnPlayerJoined`.

### Calling from gameplay

```verse
if (CPlayer := Manager.GetGamePlayer(Agent)?):
    if (CPlayer.Services.InventoryManager.HasItem("Key", 1)):
        CPlayer.Services.InventoryManager.RemoveItem("Key", 1)
```

Look up through the manager — do not assume a cached `game_player` without the
registry.

### Gotchas

- Same bus race as every system: Subscribe **and** InitializeAll walk.
- Handler signature must match `player_connected_to_game`.
- Persist row must already exist (`Init` on the manager ran first).
- Carry inventory in every shared-table `Update…` helper.
- Stable string `ItemId`; confirm granter APIs via digest.
