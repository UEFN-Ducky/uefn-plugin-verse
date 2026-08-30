---
description: "Owned custom firearms — persist on the shared player table, collectible_object_device pickup, canvas shop, rejoin grant; one sequence"
metadata:
  order: 33
  label: "Game systems — owned custom weapons (persist + collectible + canvas shop)"
  default_enabled: false
  load_condition: "Custom player weapons that save, collect via collectible_object_device, canvas-shop, upgrade, restore on rejoin, or pick up a collectible and shoot"
---

## Owned custom weapons — one loop

Prefab authoring (mesh, Armory template, `fort_trace_weapon_component`):
`skill_read_subskill("scenegraph", "custom_weapons")`. Do not re-author the gun
here. **This file is the session hotbar grant** — copy the Verse below.

Canvas chrome: `sys_canvas_cookbook` + `sys_custom_buttons` + `sys_ui_menus`
(`.All`). Wallet spend: `sys_economy`. Persist store: `persistence`.

Soft `ItemId` bags → `sys_inventory`. Stock Fortnite guns → `itemization`.
Non-weapon items → `custom_items`.

### Two inventories (do not mix)

| Layer | What it is | Survives leave? |
|-------|------------|-----------------|
| **Catalog** | Designer `WeaponId`, cost, upgrade tracks, which Armory prefab | Asset |
| **Persist** | Owned / Unlocked / `UpgradeLevels` / Equipped, nested on the **one** player `weak_map` | Yes |
| **Session hotbar** | Armory entity on `inventory_component` | **No** — re-grant |

Wallet is another nest on that **same** table. Island cap is **4 persist
`weak_map`s**. Never a second player map for guns. Session scores are session
maps, not persist.

`WeaponId` is the persist key. Prefab class is the Armory family from
`custom_weapons` (several ids may share one prefab).

Island Settings **must** have BR-style inventory
(`ItemizationConfiguration_BRStyle` —
`skill_read_subskill("islandsettings", "recipes")`) or grant can succeed and
the hotbar stays empty.

### Persist (ADD-ONLY)

```verse
owned_weapon_entry <public> := class<final><persistable>:
    WeaponId <public> : string = ""
    Owned <public> : logic = false
    UpgradeLevels <public> : []int = array{}
    Equipped <public> : logic = false

player_weapon_table <public> := class<final><persistable>:
    Version <public> : int = 1
    UnlockedWeaponIds <public> : []string = array{}
    OwnedWeapons <public> : []owned_weapon_entry = array{}
```

Nest `PlayerWeapons` on the shared player table. Every `Update*` copies **every**
sibling field (`sys_persistence_migration`). Rebuild+`set`. Never mutate in
place; never remove player keys.

`Unlocked` = shop can show Buy. `Owned` = player has it. Both live on this nest.

Persist and grant are **separate**. Persist is for rejoin / shop. Grant is the
gun in the hands. **Never skip grant because a persist `set` failed.**

### Folder (HARD)

`EP_*{}` constructors are legal only in the Verse module that owns the Assets
prefab — typically `Content/Prefabs/Weapons/`. Shop / HUD under
`Content/Verse/WeaponUpgrade/` **cannot** construct `EP_*`. Pickup that grants
must live next to the prefabs (or a pump there restores from persist).

Do not declare the same `*_device` class in both folders.

### The grant (only grant — copy this)

Wait until the agent has `inventory_component` (it is on a **descendant**, not
the agent). Construct a **fresh** Armory prefab. `AddItemDistribute` is **not**
enough — `AddResult.Ok` / `GetSuccess[]` can be true while the gun is still
unparented and unwieldable. Parent then Equip:

```verse
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Armory }
using { /Fortnite.com/Itemization }
using { /UnrealEngine.com/Itemization }
using { /Verse.org/SceneGraph }

GetFirstInventory<public>(Agent : agent)<transacts><decides> : inventory_component =
    (for (Inv : Agent.FindDescendantComponents(inventory_component)) do Inv)[0]

WaitForInventory<public>(Agent : agent)<suspends> : logic =
    var Ready : logic = false
    var Tries : int = 0
    loop:
        if (GetFirstInventory[Agent]):
            set Ready = true
            break
        if (Tries >= 50):
            break
        set Tries += 1
        Sleep(0.1)
    Ready

# Gun is already constructed (EP_YourGun{}). Do not case AddItemDistribute.
AddOwnedGun<public>(Inventory : inventory_component, Gun : entity) : void =
    if (IC := Gun.GetComponent[item_component]):
        Inventory.AddItemDistribute(Gun)
        if (IC.GetParentInventory[]):
            IC.Equip()
            return
        if (IC.PickUp[Inventory]):
            IC.Equip()
            return
        Gun.RemoveFromParent()
    else:
        Gun.RemoveFromParent()

GrantOwnedWeapon<public>(Agent : agent, WeaponId : string)<suspends> : void =
    if (WeaponId = ""):
        return
    Ready := WaitForInventory(Agent)
    if (Ready = false):
        return
    if (Inventory := GetFirstInventory[Agent], Gun := MakeOwnedArmoryGun(WeaponId)?):
        AddOwnedGun(Inventory, Gun)
```

`MakeOwnedArmoryGun` is `option{EP_YourPistol{}}` / rifle / shotgun keyed by
`WeaponId`. Apply saved upgrade levels onto this **new** entity before
`AddOwnedGun` (never `SetDamage` on a held gun and expect it to save).

Clear the previous owned trace gun first if the island is one-gun (`RemoveItem`
each `fort_trace_weapon_component` descendant).

`item_granter_device` **cannot** grant a custom Armory prefab. Stock WID
granter is a fallback for `/Fortnite.com/Weapons` classes only — not `EP_*`.

### Pickup = `collectible_object_device`

The Collectible mesh is **look only**. It does **not** put an Armory gun in
inventory. Wire `@editable Collectible` and subscribe `CollectedEvent`:

```verse
weapon_collectible_pickup_device := class(creative_device):
    @editable Collectible : collectible_object_device = collectible_object_device{}

    OnBegin<override>()<suspends> : void =
        Collectible.CollectedEvent.Subscribe(OnCollected)

    OnCollected(Agent : agent) : void =
        spawn{ OwnAndGrantWeapon(Agent, WeaponIdPistol) }
```

`OwnAndGrantWeapon` = optional persist write, then **always**
`GrantOwnedWeapon`. Prefer a **typed** device per gun (hardcoded id) over a
new `@editable WeaponId` on an already-placed class — new field names may
never hash. Reuse field name `Collectible` so the existing hash wires.

Do not drag the Armory prefab into the level as loot. Do not put the
collectible in the Item Granter.

A Collectible already taken **this session** will not fire again. Test in a
**new** play session.

### Rejoin / shop (when grant cannot live in the shop module)

1. Persist Unlock / SetOwned / IncrementUpgrade / SetEquipped (carry-all).
2. If the shop file cannot construct `EP_*`, bump a persist tick; a pump
   device in `Prefabs/Weapons` reads persist and runs `GrantOwnedWeapon`.
3. Pickup in `Prefabs/Weapons` grants directly — no pump required.

Upgrade is persist int++ then a **fresh** grant, not mutate-held.

### Canvas shop

Open with `ui_input_mode.All` (`sys_ui_menus`). Layout from
`sys_canvas_cookbook`; clicks from `sys_custom_buttons`. **Read persist** to
draw rows. Mutate leaves; rebuild only when row count changes
(`sys_hud_template`).

| Mode | Persist | Click |
|------|---------|-------|
| Locked | not Unlocked | hint only |
| Buy | Unlocked, not Owned | spend wallet → SetOwned → SetEquipped → grant |
| Equip | Owned, not Equipped | SetEquipped → grant |
| Equipped | Owned and Equipped | no-op |

Upgrade buttons only if **Owned**. Spend → IncrementUpgrade → SetEquipped →
grant (same `AddOwnedGun` sequence). Stat clamps live in `custom_weapons`.

### Hard don'ts

- A second persist `weak_map` for weapons.
- Dragging the Armory prefab as pickup.
- `item_granter_device` / `sys_inventory` bags as the owned-gun store.
- Button+`GrantItem` as the weapon shop (`sys_economy` is wallet only).
- Mutating the held entity and expecting it to save.
- Gating grant on persist `set` succeeding.
- `case (AddResult)` / `GetSuccess[]` then `Equip()` with no `PickUp`.
- Skipping `WaitForInventory`.
- Constructing `EP_*` from a Verse folder that is not the prefab module.

### Failure table

| Symptom | Cause |
|---------|-------|
| Picked collectible, cannot shoot | Collectible is look-only; grant missing, unwired, or used `AddResult.Ok` only |
| Grant “works”, empty hotbar | No BR-style `CustomInventoryConfiguration` |
| Persist saved, no gun this session | Grant gated on persist `set` |
| Shop click / rejoin empty | Shop cannot construct `EP_*` and no Prefabs pump |
| Pickup never fires again | Same session — Collectible already collected |
| `WeaponId` editable will not set | New field never hashed — typed device + hardcoded id |

### Related

| Need | Load |
|------|------|
| Prefab mesh / Armory template | scenegraph `custom_weapons` |
| Persist nest + carry-all | `persistence` + `sys_persistence_migration` |
| Spend | `sys_economy` |
| Island hotbar config | islandsettings `recipes` |
| Canvas / buttons / `.All` | `sys_canvas_cookbook`, `sys_custom_buttons`, `sys_ui_menus` |
