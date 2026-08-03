---
source_plugin_id: verse
name: verse
description: "Writing Verse code — syntax, best practices, and finding APIs/assets via digests"
license: Ducky Source-Available License v1.0
metadata:
  label: UEFN Verse
  version: 25
  managed_by: uefn-ducky
  author: UEFN-Ducky
  copyright: Copyright 2026 UEFN-Ducky
  allow_redistribute: false
---

# Verse — writing code for UEFN

**Never guess API names, types, or signatures — search the digests.** Every engine class, function, device, weapon, and every custom asset in the project is listed there. If a name is in no digest, it does not exist in this project — don't write it.

**Folders before files (hard rule):** NEVER write new `.verse` files at `Content/Verse/` root. One gameplay system per folder. Prefer template packs (`verse_template_apply`) which create `Verse/Economy/`, `Verse/Shop/`, `Verse/PlayerCore/`, `Verse/Progression/`, etc. Hand-writing: `workspace_list_dir("Verse")` → reuse that system’s folder or write `Verse/<System>/<file>.verse` (`workspace_write_file` creates parent dirs). Only `module_declarations.verse` and tiny shared helpers belong at Verse root. Before inventing a parallel layout, load `modules`.

**Player managers (`game_player` + `Services`):** follow `sys_architecture` exactly — `player_manager` bus → `Init` (persist row) → manager `OnPlayerJoined` (config then HUD). Name roles Manager / Tracker / Controller / Service — not everything is a “system”. Never use `fortnite_` in type names. Never name things “wallet” or “*_system” — use `economy_manager`, `progression_manager`, `player_time_tracker`, `save_service`.

**Any on-screen canvas (shop / inventory / HUD / modal / grid):** `sys_canvas_cookbook` (compositions + visibility checklist) → `sys_hud_template` (ShowHUD wiring) → interactive clicks use `sys_ui_menus` (`.All`). Skills alone must invent UI that **shows visually**.

**Designer UMG User Widget (`UW_*`, Verse fields 38.00+, field events 39.40+):** `umg_widgets` first → `umg_verse_fields` / `umg_verse_field_events` / `umg_view_bindings` / `umg_ui_materials`. MCP create/inspect: `umg_mcp_tools` (`umg_capabilities` before other umg_* tools). Never invent a placeholder `MyUMGWidget := class:` — types come from the Assets digest.

## Verse templates (before you invent a system)

When the **UEFN Verse** plugin is enabled, **check packs before writing** player/economy/progression/tycoon/shop/timer scaffolds:

1. `verse_template_list()` — see ids, folders, file paths, and which `?option` slots each pack registers/consumes.
2. `verse_template_get(id)` — read the Verse source.
3. `verse_template_apply(id)` — creates a **named folder** under `Content/Verse` (e.g. `Verse/Economy/`) and writes the pack files there. Prefer this over inventing parallel files at Verse root.

Pack names match `sys_architecture` (`player_core`, `economy`, `progression`, `time_tracker`, `shop`, `match_timer`, `tycoon`). Cross-pack links use `player_manager` `?option` slots (`GetCurrencyProvider`, `GetXPAwarder`, `GetPlaytimeProvider`) so packs stay standalone.

## Digests (before you write)

UEFN generates digest files covering the whole surface. **Listener offline OK** — tools read digests from disk. Start with `list_verse_digests()` to see which files exist and what each is for:

| Digest | Purpose |
|--------|---------|
| `Fortnite.digest.verse` | Epic gameplay API — devices, items, `agent`, playspace |
| `Verse.digest.verse` | Core language + SceneGraph / Simulation / SpatialMath |
| `UnrealEngine.digest.verse` | Engine APIs exposed to Verse (math, mesh types) |
| `Assets.digest.verse` | **Your custom assets** as Verse identifiers (materials, meshes, prefabs) |

- `search_verse_digest(query)` — ranked keyword search (`{path, line, text, module}`). Digests run up to ~1 MB: **search, never dump**.
- `get_verse_api(name)` — full declaration + members/docs for one identifier.
- `list_verse_types(kind=, digest=, name_filter=)` — enumerate everything (e.g. `name_filter="_device"`, `digest="assets"`).
- `list_verse_devices()` — device class names (`_device` / `creative_device` parent).
- Pass `digest_path=` the Assets digest to search only custom assets.
- Content Browser weapon/item *assets* → `search_assets` (digests cover Verse API + Verse-visible ids).

Workflow: `list_verse_digests` / search → `get_verse_api` for the exact signature → write with that **exact** name → `workspace_list_verse_errors`.

## Error checks

- **FIRST tool on a fix-errors turn:** `workspace_list_verse_errors()` — never `ping`, `get_project_info`, `ducky_get_errors`, `execute_python`, or listener tools. If a listener call does not return immediately it is broken; do not retry.
- `workspace_list_verse_errors()` with **no args** after every edit (incremental; offline OK). Its list is complete — fix the files it names; don't re-scan to "make sure" and never pass `full=true` just to re-confirm (full rescan is slow). `rescan=false` re-reads without scanning.
- `workspace_compile_verse` only after Problems is clean and UEFN is known open (not a substitute for listing errors).

## Syntax must-knows

- **Comments:** `#` line, `<# … #>` block. **Never** `//`.
- **Bindings:** `X := value` defines (immutable); `var X : t = value` is mutable — reassign with `set X = value`.
- **Types are lowercase:** `int float logic string void`; booleans are `logic`. Containers: `[]t` array, `[k]v` map, `?t` option, `tuple(...)`.
- **Effects in `<>`:** `<suspends>` (async), `<decides>` (can fail — call inside a failure context), `<transacts>`, `<computes>`. Access: `<public> <private> <internal> <protected>`, plus `<override> <final> <native>`.
- **Failure context:** failable expressions live inside `if (…)`, `for (…)`, or `[]`. `if (V := Map[Key]) { }`; unwrap an option with `X?`.
- **A placed device** is a `creative_device` subclass with `@editable` fields and `OnBegin`:

```verse
my_device := class(creative_device):
    @editable Trigger : trigger_device = trigger_device{}
    OnBegin<override>()<suspends>:void =
        Trigger.TriggeredEvent.Subscribe(OnActivated)
    OnActivated(Agent : ?agent):void =
        if (A := Agent?):
            Print("triggered")
```

## Anti-patterns

| Wrong | Right |
|-------|-------|
| Dump `economy_shop.verse` / devices at `Verse/` root | `Verse/Economy/…`, `Verse/Shop/…`, or `verse_template_apply` |
| Guess a device / asset / function name | `search_verse_digest` first; copy the exact signature |
| `// comment` | `#` comment |
| Read a whole `*.digest.verse` into chat | `search_verse_digest` (compact matches) |
| Hunt compile errors via the game / listener / `ping` / `get_project_info` / `execute_python` / `ducky_get_errors` | `workspace_list_verse_errors` FIRST (host) |

For anything non-trivial, load the matching reference below with `skill_read_subskill` — deep language topics (`classes`, `control_flow`, `async`, `effects`, `devices`, `datatypes`, `persistence`, `ui`, `modules`, `digests`) and `sys_*` recipes for whole game systems. **Start any new game system with `sys_architecture`** — the backbone the other `sys_*` recipes specialize.

## Reference files

Read the matching file before working in that area:

- `references/digests.md` — Where the Verse API and your custom assets live, and how to search them
  Load when: Looking up a device, weapon, type, function signature, or a custom asset before writing Verse
- `references/syntax.md` — Verse language reference — types, effects, control flow, classes, concurrency
  Load when: Writing non-trivial Verse — control flow, classes/structs, options/failure, or concurrency
- `references/classes.md` — How to declare classes, structs, enums, interfaces — every specifier, members, methods, subclassing, parametric types
  Load when: Creating or subclassing a class/struct/enum/interface, or unsure which class specifier (<concrete>/<unique>/<final>/<persistable>) to use
- `references/control_flow.md` — Control flow — if / else, the if:/then:/else: block form, all for-loop shapes, loop/break, case, and how failure drives branching
  Load when: Writing branching or iteration — if/for/loop/case, ranges, map iteration, filters, or break/return
- `references/async.md` — Async vs synchronous Verse — what <suspends> means, spawn/race/sync, Sleep/Await, event subscriptions, and the rules for calling async code
  Load when: Anything time-based or event-driven — loops with Sleep, spawn, race, Await, waiting on events, or 'is this function async?'
- `references/effects.md` — Effect specifiers (<suspends> <decides> <transacts> <computes> <localizes> …), the failure model, <decides> functions called with [], and option handling
  Load when: Choosing effect specifiers for a function, calling a failable [] function, or handling options (?t, X?, option{})
- `references/devices.md` — creative_device pattern — @editable fields, OnBegin, subscribing to device/player events, agents vs players, GetPlayspace, and the wrapper helpers
  Load when: Writing a placed device — @editable wiring, OnBegin, subscribing to triggers/buttons/player events, or working with agent/player/fort_character
- `references/datatypes.md` — Data — scalars, arrays/maps/tuples/options, bindings & mutation, arithmetic, string/number formatting, and collection operations (Length, iteration, +=)
  Load when: Working with numbers/strings/arrays/maps/tuples, mutating state (var/set), or doing math/formatting
- `references/persistence.md` — Player persistence — weak_map, class<final><persistable>, versioning, the PlayerStatsMap pattern, and immutable update-and-store manager functions
  Load when: Saving player data across sessions — weak_map, <persistable> classes, or reading/writing per-player stats
- `references/ui.md` — Building UEFN UI in Verse — canvas, overlay, stack_box and their slots, text_block/texture_block/color_block widgets, alignment, padding/margin, and the canvas-builder pattern
  Load when: Creating on-screen UI/HUD widgets — canvas, overlay, stack_box, text_block, texture_block, alignment or slots
- `references/sys_canvas_cookbook.md` — Universal Verse canvas cookbook — invent any on-screen UI (shop, inventory, HUD, modal, grid) that shows visually; compositions, visibility checklist, drive from any Services manager
  Load when: Creating any Verse canvas UI — shop, inventory, HUD, modal menu, tabbed panel, item grid, progress bar, or dynamic cell board that must show on screen
- `references/modules.md` — Project structure — module declarations, using {} imports (engine paths vs project modules), how folders map to modules, and cross-file references
  Load when: Organizing code across files — module declarations, using imports, or referencing a type/manager defined in another folder
- `references/sys_architecture.md` — The backbone for building ANY player-driven game system — manager device + game_player + manager bundle + weak_map, and how the pieces plug together
  Load when: Designing or extending any game system (score, economy, progression, stats…) — how player_manager, game_player, Services and persistence fit together
- `references/sys_player_data.md` — Game player data & the player registry — the [agent]game_player map, join/leave lifecycle, the typed custom event bus (type{_()}), and elimination handling
  Load when: Tracking per-player data, handling join/leave/elimination, or building a custom event/subscribe system
- `references/sys_scoring.md` — Score keeping & leaderboards — persistent vs per-session scores, the reference-class trick for cheap updates, sorting, per-player leaderboard canvases, and rank rewards
  Load when: Building score keeping, kill/death tracking, streaks, leaderboards, ranks, or rank-based rewards
- `references/sys_economy.md` — Currency & economy — the wallet manager, currency config, buy-with-currency shops, granting items, HUD feedback, and scaled/suffixed currency values
  Load when: Building currency/wallet, shops, purchases, item granting, or a scaled money display (K/M/B suffixes)
- `references/sys_progression.md` — XP & level progression — persistable level data, editable level thresholds, the level manager, progress bar, level-up detection, effects and analytics
  Load when: Building XP, levels, ranks with thresholds, level-up rewards/effects, or a progress bar HUD
- `references/sys_rounds_timers.md` — Round flow & timers — the game state machine (phase functions chained by events), custom timer devices with typed events, and real delta-time loops with GetSimulationElapsedTime
  Load when: Building match/round flow, game phases/state machine, countdowns, or a custom timer with events
- `references/sys_spawning.md` — Spawning & movement — NPC waves, pre-placed props, runtime SpawnProp delivery paths, MoveTo/nav, teleport-until-success, pools
  Load when: Spawning enemies/props/waves, runtime delivery props, moving objects along paths, tracking NPC eliminations, or teleporting players reliably
- `references/sys_persistence_migration.md` — Evolving saved data safely — the Version field, why defaulted persistable fields are backward-compatible, and one-time migration on load
  Load when: Changing the shape of already-saved player data — adding/removing persistable fields, or migrating old saves to a new schema
- `references/sys_teams.md` — Teams — the team collection API, reading/assigning a player's team, per-team counts and iteration, and role/team-based game logic
  Load when: Building team-based or role-based logic — assigning teams, counting per team, team scoring, or per-team behavior
- `references/sys_generators.md` — Idle / tycoon systems — passive resource generators, upgrade tiers, collect-on-tick loops, and offline/away earnings orchestration with TimeTracker
  Load when: Building tycoon/idle mechanics — passive income generators, buildings/upgrades with tiers, or offline earnings
- `references/sys_hud.md` — Per-player HUD management — the [agent]canvas widget map, add/remove/refresh, input modes, live text/image updates, and where to own HUD state
  Load when: Managing on-screen HUD across many players — showing/hiding/updating widgets per player, input modes, or live-updating text/bars
- `references/sys_analytics.md` — Analytics & accolades — submitting tracked events per player, organizing analytics/accolade devices into bundles, and firing from gameplay milestones
  Load when: Adding analytics/telemetry events, tracking funnels/milestones, or awarding accolades/XP for actions
- `references/sys_time_tracking.md` — Session & playtime tracking — persistable login timestamps, epoch-seconds vs simulation clock, join/leave session lifecycle, offline-elapsed calculation, and formatted duration display
  Load when: Tracking playtime, first/last login, session duration, offline elapsed time, or real-world timestamps across sessions
- `references/sys_inventory.md` — Per-player inventory — persistable item entry arrays, immutable add/remove, quantity checks, re-granting physical items on load, and per-entry persist vs reset flags (soft bags + Creative granters; player custom firearms → scenegraph `custom_weapons`)
  Load when: Building a per-player item inventory, owned-collection, stackable items, re-granting items on join, or persist vs session-reset item flags
- `references/sys_hud_template.md` — Any-manager display template — *_canvas_builder, ShowHUD/RemoveHud, shop rows, inventory slots, progress bars; driven by any Services manager
  Load when: Creating per-player on-screen UI for any manager — wallet, XP, shop rows, inventory slots, tabs, progress bars — canvas_builder and ShowHUD
- `references/sys_input_devices.md` — Input devices — input_trigger_device Register/Unregister, Pressed/Released, held-key repeat, UI buttons vs Creative triggers
  Load when: Wiring input_trigger_device, Register/Unregister per agent, held movement keys, or choosing UI buttons vs Creative input triggers
- `references/sys_ui_menus.md` — Interactive UI menus — modal popups, shops, collect screens with ui_input_mode.All, button_loud, open/close
  Load when: Building interactive Verse UI — shops, collect popups, pickers, tabbed menus with button clicks and ui_input_mode.All
- `references/sys_minigame_overlay.md` — Overlay minigames — per-agent instance map, stasis, dynamic canvas grid, input_trigger movement, game loop, cleanup
  Load when: Building an on-screen overlay or grid minigame — dynamic color_block cells, stasis, input triggers, per-player game instances
- `references/sys_buildings.md` — Building unlock & reveal — paid upgrades via economy, underground Z-teleport prop swap, nav coupling for delivery paths
  Load when: Unlocking or upgrading buildings/plots, teleporting props to reveal tiers, coupling unlocks to delivery nav paths
- `references/sys_npc_ai.md` — NPC AI — npc_behavior templates, nearest-player lookup, spread/strafe, centralized damage, Scene Graph projectiles, wave spawn managers
  Load when: Writing npc_behavior subclasses, enemy AI loops, melee/ranged combat, Scene Graph projectiles, or npc_spawner wave managers
- `references/umg_widgets.md` — UMG User Widgets — when to use UMG vs Verse canvas, UW_* Assets digest lookup, AddWidget/RemoveWidget, myths table
  Load when: Creating or driving a UMG User Widget / Widget Blueprint from Verse, or deciding UMG vs canvas
- `references/umg_verse_fields.md` — Verse fields in UMG (38.00+) — declare fields, View Bindings, set from creative_device, Style1/Style2 example
  Load when: Driving a UMG widget with Verse fields (progress, message, material, texture, logic)
- `references/umg_verse_field_events.md` — Verse field events (39.40+) — Button OnClicked → event() fields, Subscribe once, Await helpers
  Load when: Handling UMG button clicks / widget events from Verse
- `references/umg_view_bindings.md` — View Bindings & viewmodel — ToText, textures, conversion functions, one-way vs two-way
  Load when: Wiring View Bindings or a viewmodel on a User Widget
- `references/umg_ui_materials.md` — UI materials & textures — Fortnite UI Material folder, MI_* Verse fields, material-parameter conversions
  Load when: Using UI materials/textures on a User Widget or migrating from the UI Feature Template
- `references/umg_mcp_tools.md` — UMG MCP tools — umg_capabilities first, create/inspect/tree/bindings, schema-dump crash ban
  Load when: Using umg_* tools to create or edit Widget Blueprints
