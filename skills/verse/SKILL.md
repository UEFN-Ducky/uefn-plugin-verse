---
source_plugin_id: verse
name: verse
description: "Writing Verse source — syntax, effects (no_rollback/transacts/decides), structured concurrency, compile-error fixes, system recipes, and finding APIs via digests. Source only: placed-device wiring and level ops → uefn skill; Scene Graph entities/prefabs → scenegraph skill."
license: MIT
metadata:
  label: UEFN Verse
  version: 44
  managed_by: uefn-ducky
  author: UEFN-Ducky
  copyright: Copyright 2026 Mindful Path Company, LLC
  allow_redistribute: true
---

# Verse — writing code for UEFN

**Tool order (HARD):** 1) Official UEFN MCP first — `ducky_get_status`; when `epic_mcp_online` use nested `unreal__*` (`unreal__list_toolsets` → `unreal__describe_toolset` → `unreal__call_tool`; 5+ ops → ProgrammaticToolset `execute_tool_script`). 2) Ducky listener second (Epic-offline gaps + Ducky-only tools listed in this skill). 3) `execute_python` LAST — never a placement/layout path, even if Epic and listener already failed. Never spawn, move, or assign materials. Map: `skill_read_subskill("uefn", "epic_mcp")`.

Verse *source* on disk still starts with `workspace_list_verse_errors` / `workspace_*`. This tool order is for compile, place, UMG, and devices.

In-editor Verse build / file ops when Epic is online: `ValkyrieToolset.VerseToolset` (`BuildAll`, `ReadFile`, …). Offline disk edits stay on `workspace_*`.

**CRITICAL — level place/wire is SERIAL (uefn tools):** when placing devices or
wiring `@editable` refs, one heavy MCP call → wait → next. Never parallel
`spawn_actor` / `wire_verse_*` / `save_current_level`. First array item and
rewrites stay on the **same** Verse device — never `_v2`:
`skill_read_subskill("uefn", "verse_devices")`. SFX fields use Creative
**Audio Player** (`audio_player_device`). Details:
`skill_read_subskill("uefn", "batch_commands")` and `creative_devices`.


**Never invent API names.** Copy names and signatures from a loaded skill or template as-is; for any name no loaded skill shows, `search_verse_digest` once — if it is in no digest it is almost certainly invented (`Log10`, `MoveToLocation`, `team_selector`, `timer_device.Reset` do not exist). Exception: core intrinsics `Abs`, `ConcatenateMaps`, `Max`, `Min` are not listed in the digests yet compile — the build's "Unknown identifier" is the final word. Epic doc samples also omit `using` lines; add them. Budget ~5 lookups per task, then write.

**Effects decide whether your code compiles (HARD):** a function with **no effect specifier is `no_rollback`** and cannot be called inside `if (…)`, `if:`, `for` filters, `[]`, or a `<decides>` body. Give every getter/helper `<transacts>`; pair `<decides>` with `<transacts>`; field initialisers are literals only; `int / int` is failable and `rational`; never name a binding `Distance`. These four rules were 72 % of all real compile errors. Details: `effects`; fixes by error code: `compile_errors`.

**Concurrency:** inside `<suspends>` code use `branch` (cancelled with the scope), `race` (first wins, rest cancelled), `sync` (all), `rush` (first wins, rest continue); `spawn` only from sync handlers or for device-lifetime loops. Details: `async`.

**Folders before files (hard rule):** NEVER write new `.verse` files at `Content/Verse/` root. One gameplay system per folder. Prefer template packs (`verse_template_apply`) which create `Verse/Economy/`, `Verse/Shop/`, `Verse/PlayerCore/`, `Verse/NPCCore/`, `Verse/Progression/`, etc. Hand-writing: `workspace_list_dir("Verse")` → reuse that system’s folder or write `Verse/<System>/<file>.verse` (`workspace_write_file` creates parent dirs). Only `module_declarations.verse` and tiny shared helpers belong at Verse root. Before inventing a parallel layout, load `modules`.

**Player managers (`game_player` + `Services`):** follow `sys_architecture` exactly — `player_manager` bus → `Init` (persist row) → manager `OnPlayerJoined` (config then HUD). Name roles Manager / Tracker / Controller / Service — not everything is a “system”. Never use `fortnite_` in type names. Never name things “wallet” or “*_system” — use `economy_manager`, `progression_manager`, `player_time_tracker`, `save_service`.

**Persistence `weak_map` (HARD):** never remove keys once added (removing breaks saves); never delete persistable fields without migration. Replace values only via rebuild+`set`. Load `persistence` + `sys_persistence_migration` before any save-schema change. Session maps ≠ persist maps. Nest owned custom weapons on the **one** player table (`sys_owned_weapons`); never a 5th persist `weak_map`.

**Any on-screen canvas (shop / inventory / HUD / modal / grid):** `sys_canvas_cookbook` (compositions + visibility checklist) → `sys_hud_template` (ShowHUD wiring) → interactive clicks: **`sys_custom_buttons`** (chrome-less whole-card/row `button`, hover, **`SetFocus` before AddWidget**) then `sys_ui_menus` (`.All` lifetime). Armory owned-weapon shop (Locked / Buy / Equip / upgrade) → `sys_owned_weapons`. Skills alone must invent UI that **shows visually**.

**Epic Text Localization / PO / publish L10N readiness:** named `<localizes>` + `message` for gatherable copy — `skill_read_subskill("localization", "ui_ready")` (pipeline: `localization` pack).

**Designer UMG User Widget (`UW_*`, Verse fields 38.00+, field events 39.40+):** `umg_widgets` first → `umg_verse_fields` / `umg_verse_field_events` / `umg_view_bindings` / `umg_ui_materials`. MCP create/inspect: `umg_mcp_tools` (`umg_capabilities` before other umg_* tools). Never invent a placeholder `MyUMGWidget := class:` — types come from the Assets digest.

## Verse templates (before you invent a system)

When the **UEFN Verse** plugin is enabled, **check packs before writing** player/economy/progression/tycoon/shop/timer scaffolds:

1. `verse_template_list()` — see ids, folders, file paths, and which `?option` slots each pack registers/consumes.
2. `verse_template_get(id)` — read the Verse source.
3. `verse_template_apply(id)` — creates a **named folder** under `Content/Verse` (e.g. `Verse/Economy/`) and writes the pack files there. Prefer this over inventing parallel files at Verse root.

Every pack was built in UEFN with zero errors (Sep 2026); `verse_template_verify()` re-runs that build for all installed templates when UEFN is open (stages, compiles, removes). Note the island cap: Player Core + Economy + Progression + Time Tracker use all **four** allowed persistent `weak_map`s — a fifth anywhere is error 3502.

Pack names match `sys_architecture` (`player_core`, `npc_core`, `economy`, `progression`, `time_tracker`, `shop`, `match_timer`, `tycoon`). NPC islands: `verse_template_apply("npc_core")` then customize (do not invent a parallel prey/hunter folder). `npc_ecosystem` is the optional cat+dog example only. Cross-pack player links use `player_manager` `?option` slots (`GetCurrencyProvider`, `GetXPAwarder`, `GetPlaytimeProvider`) so packs stay standalone.

## Digests (before you write)

**HARD — digests are READ ONLY; UEFN auto-edits them.** Never write/edit/delete/rename any `*.digest.verse`. After new assets or Verse that should appear in digests: prefer nested Epic Verse compile (`unreal__*`) when `epic_mcp_online`; `workspace_compile_verse` still works as the host Verse-build trigger. Then look inside with `search_verse_digest` / `get_verse_api`. Project Verse goes under `Content/Verse/**` only.

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

Workflow (only for names no loaded skill shows): search → `get_verse_api` for the exact signature → write with that **exact** name → `workspace_list_verse_errors`. Batch independent digest lookups in one message; budget ~5 lookups per task, then WRITE the files — the error list drives any re-checks.

## Error checks

- **FIRST tool on a fix-errors turn:** `workspace_list_verse_errors()` — never `ping`, `get_project_info`, `ducky_get_errors`, `execute_python`, or listener tools. If a listener call does not return immediately it is broken; do not retry.
- `workspace_list_verse_errors()` with **no args** after every edit (incremental; offline OK). Fix the files it names; don't re-scan to "make sure" and never pass `full=true` just to re-confirm. `rescan=false` re-reads without scanning.
- **The LSP scan is not a build.** It cannot see effect errors (3512 no_rollback, 3582 divergent initialiser), module-access errors (3593) or ambiguous identifiers (3588/3532) — 72 % of real failures. A clean Problems panel means "syntax OK", nothing more.
- **`workspace_compile_verse` is mandatory** once Problems is clean and before any `wire_verse_device_ref` / `wire_verse_device_array` / `set_verse_editable` / `set_npc_definition_behavior` / `workspace_push_verse_changes`. Wiring before a build fails with "STALE REFLECTION" because fields have no compiled hash. Prefer nested Epic `VerseToolset` BuildAll when `epic_mcp_online`. If a wire still returns STALE REFLECTION, **stop** — the host already retried once; wait for the build, re-inspect, do not hammer.
- Any `Script error NNNN` → load `compile_errors`, jump to the code, apply the fix at the reported line, rebuild.

## Syntax must-knows

- **Comments:** `#` line, `<# … #>` block. **Never** `//`.
- **Bindings:** `X := value` defines (immutable); `var X : t = value` is mutable — reassign with `set X = value`.
- **Types are lowercase:** `int float logic string void`; booleans are `logic`. Containers: `[]t` array, `[k]v` map, `?t` option, `tuple(...)`.
- **Effects in `<>`:** `<suspends>` (async), `<decides>` (can fail — call with `[]`, pair with `<transacts>`), `<transacts>` (rollback-safe; use for every getter/helper), `<computes>` (pure), `<converges>` (field initialisers). **No specifier = `no_rollback`** → not callable in any failure context. Access: `<public> <private> <internal> <protected>`, plus `<override> <final> <native>`.
- **Failure context:** failable expressions live inside `if (…)`, `if:`, `for (…)`, or `[]`. `if (V := Map[Key]) { }`; unwrap an option with `X?`. A `<transacts>` body is **not** a failure context.
- **One-line signatures**, `_` reserved, tuples `T(0)`, `int / int` is `rational`, `array{}` not `array:`, no `ToString(logic)`, a `{}` body goes on the same line as its `if (…)` (a lone `{}` on the next line is parse error 3100) — see `syntax`.
- **A placed device** is a `creative_device` subclass with `@editable` fields and `OnBegin`:

```verse
using { /Fortnite.com/Devices }
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
| Guess a device / asset / function name | Copy it from a loaded skill, else `search_verse_digest` once |
| Helper with no effect called inside `if (…)` | `<transacts>` on the helper, or bind to a local first |
| Wire `@editable` refs right after writing Verse | `workspace_compile_verse` first, then wire |
| Treat a clean `workspace_list_verse_errors` as "it compiles" | It is syntax-only; the build finds effect/module errors |
| `spawn` a per-round loop inside `<suspends>` code | `branch` (dies with the scope) or `race` against the end event |
| `// comment` | `#` comment |
| Read a whole `*.digest.verse` into chat | `search_verse_digest` (compact matches) |
| Write / patch / delete any `*.digest.verse` | Never — UEFN auto-edits digests on Verse build; you only search/read after `workspace_compile_verse` |
| Hunt compile errors via the game / listener / `ping` / `get_project_info` / `execute_python` / `ducky_get_errors` | `workspace_list_verse_errors` FIRST (host) |

For anything non-trivial, load the 1–3 references below that best match the task with `skill_read_subskill`, then WRITE — the recipes are self-sufficient. Cross-links inside a reference ("see also" / "Details:") are optional deep-dives for when you are stuck, not prerequisites, and never re-load a reference you already read. **New player-driven game systems start with `sys_architecture`** — the backbone the other `sys_*` recipes specialize (not needed for self-contained systems like NPC behaviors).

## Reference files

Load the closest 1–3 for the task:

- `references/digests.md` — Where the Verse API and your custom assets live, and how to search them
  Load when: Looking up a device, weapon, type, function signature, or a custom asset before writing Verse
- `references/syntax.md` — Verse language reference — types, effects, control flow, classes, concurrency, hard syntax rules
  Load when: Writing non-trivial Verse — control flow, classes/structs, options/failure, or concurrency
- `references/compile_errors.md` — Compiler error catalogue: Script error code → real cause → compiling fix (3512, 3582, 3593, 3588, 3104, 3506, 3509, 3524, 3511, 3514, 3100, 9002) plus tool-side "STALE REFLECTION"
  Load when: workspace_compile_verse or the UEFN build reported a Script error, or workspace_list_verse_errors names a file
- `references/classes.md` — How to declare classes, structs, enums, interfaces — every specifier, members, methods, subclassing, parametric types
  Load when: Creating or subclassing a class/struct/enum/interface, or unsure which class specifier (<concrete>/<unique>/<final>/<persistable>) to use
- `references/control_flow.md` — Control flow — if / else, the if:/then:/else: block form, all for-loop shapes, loop/break, case, and how failure drives branching
  Load when: Writing branching or iteration — if/for/loop/case, ranges, map iteration, filters, or break/return
- `references/async.md` — Async vs synchronous Verse — <suspends>, structured concurrency (sync / race / rush / branch vs spawn), Sleep/Await, event subscriptions and payload types
  Load when: Anything time-based or event-driven — loops with Sleep, branch, spawn, race, sync, rush, Await, waiting on events, or 'is this function async?'
- `references/effects.md` — Effect specifiers (<transacts> <decides> <computes> <converges> <reads> <suspends>), what NO specifier means (no_rollback), who may call whom, the failure model, <decides> chaining, options
  Load when: Choosing effect specifiers, a compile error mentioning no_rollback / transacts / divergent, calling a failable [] function, or handling options
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
- `references/sys_damage_health.md` — Character damage, healing, health/shield and elimination — healthful/damageable/healable/shieldable on fort_character, DamagedEvent/EliminatedEvent payloads and who-hit-whom, respawn via player_spawner_device
  Load when: Applying or reacting to damage/healing, reading/setting health or shield, detecting eliminations and the eliminator, or respawning players
- `references/sys_party.md` — Party-aware gameplay (Social Synergy API, v42.10): GetLocalParty, party size, same-party checks, join/leave events, party-only doors, difficulty scaled to party size
  Load when: Anything about parties, friends who joined together, party bonuses, party-only access, or scaling difficulty to group size
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
- `references/sys_inventory.md` — Per-player inventory — persistable item entry arrays, immutable add/remove, quantity checks, re-granting physical items on load, and per-entry persist vs reset flags (soft bags + Creative granters; Armory prefab → scenegraph `custom_weapons`; owned collectible + canvas shop → `sys_owned_weapons`; custom items → scenegraph `custom_items`; template abilities → scenegraph `template_abilities`)
  Load when: Building a per-player item inventory, owned-collection, stackable items, re-granting items on join, or persist vs session-reset item flags
- `references/sys_owned_weapons.md` — Owned custom firearms — persist, collectible_object_device pickup, WaitForInventory, AddItemDistribute then GetParentInventory/PickUp/Equip, canvas shop, rejoin; Item Granter cannot grant EP_*
  Load when: Custom player weapons that save, pick up via collectible_object_device, canvas-shop, upgrade, restore on rejoin, or pick a collectible and shoot
- `references/sys_hud_template.md` — Any-manager display template — *_canvas_builder, ShowHUD/RemoveHud, shop rows, inventory slots, progress bars; driven by any Services manager
  Load when: Creating per-player on-screen UI for any manager — wallet, XP, shop rows, inventory slots, tabs, progress bars — canvas_builder and ShowHUD
- `references/sys_input_devices.md` — Input devices — input_trigger_device Register/Unregister, Pressed/Released, held-key repeat, UI buttons vs Creative triggers
  Load when: Wiring input_trigger_device, Register/Unregister per agent, held movement keys, or choosing UI buttons vs Creative input triggers
- `references/sys_custom_buttons.md` — Custom chrome-less Verse buttons — whole-card/row hit targets, HighlightEvent hover + gamepad focus, SetFocus before AddWidget, locked-but-focusable cards, ui_buttons pattern
  Load when: Building custom Verse UI buttons, whole-card/row click targets, hover chrome, gamepad/controller navigation, SetFocus, or ui_buttons.verse
- `references/sys_ui_menus.md` — Interactive UI menus — modal popups, shops, collect screens with ui_input_mode.All, open/close (button type → sys_custom_buttons)
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
