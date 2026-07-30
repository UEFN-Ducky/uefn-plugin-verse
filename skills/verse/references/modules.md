---
description: "Project structure — module declarations, using {} imports (engine paths vs project modules), how folders map to modules, and cross-file references"
metadata:
  order: 11
  label: "Modules, using & file layout"
  default_enabled: true
  load_condition: "Creating or moving .verse files, module declarations, using imports, or referencing a type/manager in another folder — ALWAYS before writing a new Verse file"
---

## Modules, `using` & file layout

Verse groups code into **modules**; `using` brings names into scope. Declare your
module tree in one place and import both engine APIs and your own modules. The
module/type names below are generic placeholders — name yours to fit your project.

### HARD RULE — folders before files

**Never dump new `.verse` files at `Content/Verse/` (or `Verse/`) root.**

| Allowed at Verse root | Everything else |
|----------------------|-----------------|
| `module_declarations.verse` | One **system folder** per concern |
| Tiny shared `helpers.verse` (optional) | Devices, managers, HUD builders, shops, … |

Canonical template folders (use these names when they fit):

| Folder | For |
|--------|-----|
| `Verse/PlayerCore/` | `player_manager`, `game_player`, persistence |
| `Verse/Economy/` | currency / economy manager + device |
| `Verse/Progression/` | XP / levels |
| `Verse/Shop/` | shop device + canvas |
| `Verse/TimeTracker/` | playtime |
| `Verse/MatchTimer/` | match / round timer |
| `Verse/Tycoon/` | generators / tycoon |

Workflow for **new** code:

1. `workspace_list_dir("Verse")` — see what folders already exist.
2. Prefer `verse_template_list` → `verse_template_apply(id)` (creates the pack folder).
3. Hand-write: `workspace_write_file("Verse/<System>/<file>.verse", …)` — parents are created automatically.
4. Update `module_declarations.verse` if you added a new module folder.
5. Load this file (`modules`) whenever you organize across folders.

Wrong: `Verse/economy_shop.verse`, `Verse/shop_hud_device.verse`, `Verse/game_session.verse`  
Right: `Verse/Shop/economy_shop.verse`, `Verse/Shop/shop_hud_device.verse`, `Verse/PlayerCore/game_session.verse`

### `using` — two kinds of import

```verse
# Engine / standard-library paths (leading slash, vendor domain)
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Random }
using { /Fortnite.com/UI }

# Your own modules (no leading slash — resolved by module name)
using { PlayerDevices }
using { Services.PlayerProgressionManager }
using { GameDevices.Gameplay }
```

Rules of thumb:

- **Leading `/`** = engine/stdlib (`/Fortnite.com/…`, `/UnrealEngine.com/…`,
  `/Verse.org/…`). Which one provides a type is in the digests — the `using`
  paths there are exactly what you import.
- **No leading `/`** = one of your own modules (e.g. `PlayerDevices`,
  `GameDevices.Gameplay`). Import the module that *contains* the type/manager
  you're calling.
- Missing a `using` → "unknown identifier" for a name that exists. Add the import
  the digest/source shows.

### Common engine imports (what each unlocks)

| `using` | Gives you |
|---------|-----------|
| `/Verse.org/Simulation` | core sim, events, `Sleep`, `spawn` machinery |
| `/Fortnite.com/Devices` | `creative_device`, `trigger_device`, granters, buttons |
| `/Fortnite.com/Characters` | `fort_character`, elimination/damage events |
| `/Fortnite.com/UI` + `/UnrealEngine.com/Temporary/UI` | canvas & widgets |
| `/UnrealEngine.com/Temporary/SpatialMath` | `vector3`, `rotation`, `Distance` |
| `/Verse.org/Random` | `GetRandomInt`, random selection |
| `/Verse.org/Colors` (+ `/NamedColors`) | `color`, named colors |

### Declaring the module tree

Modules mirror the folder layout. Declare the whole hierarchy in one file
(e.g. `module_declarations.verse` at Verse root), nesting with indentation:

```verse
PlayerDevices <public> := module:
    Services <public> := module:
        PlayerProgressionManager <public> := module:
        PlayerEconomyManager <public> := module:

GameDevices <public> := module:
    Gameplay <public> := module:
        UI <public> := module:
```

- A `.verse` file's code belongs to the module for the folder it sits in
  (`Verse/GameDevices/Gameplay/*.verse` → `GameDevices.Gameplay`).
- Mark modules `<public>` so other modules can `using` them.
- Reference a nested module by dotted path in `using`:
  `using { GameDevices.Gameplay.UI }`.

### Cross-file references

Once you `using` a module, its `<public>` types, functions, and module-level
values are in scope by name:

```verse
using { PlayerDevices }                 # brings in player_manager, PlayerStatsMap, …
# …
@editable MyPlayerManager : player_manager = player_manager{}
AllPlayers := MyPlayerManager.GetAllGamePlayers()
```

- Only `<public>` members cross module boundaries — mark them explicitly.
- Module-level `var`s (like `var PlayerStatsMap <public> : weak_map(...)`) become
  shared global state once imported. Use sparingly and keep them `<public>` only
  when other systems truly need them.

### File organization conventions

- One system per folder, one `creative_device` subclass per gameplay concern.
- Split UI construction into a `*_canvas` / `*_canvas_builder` file **in that same system folder**, separate from logic.
- Keep persistence types + the shared `weak_map` together in `PlayerCore` (or your player folder).
- Put small reusable functions/wrappers in a shared `helpers.verse` at Verse root only when many systems need them — not every one-off utility.
