---
description: "Player persistence — weak_map, class<final><persistable>, versioning, the PlayerStatsMap pattern, and immutable update-and-store manager functions"
metadata:
  order: 9
  label: "Persistence — weak_map & persistable"
  default_enabled: false
  load_condition: "Saving player data across sessions — weak_map, <persistable> classes, or reading/writing per-player stats"
---

## Persistence — `weak_map` & `<persistable>`

Player data that survives between sessions lives in a **`weak_map` keyed by
`player`**, holding a `<persistable>` class. Centralize it in one file so every
system shares the same store. Type names below are generic — adapt to your game.

### HARD RULE — persistence is immutable

- **Keys are append-only.** Once `set PlayerStatsMap[Player] = …` succeeds, **never**
  remove, clear, or filter that key out. Removing a key from a persistence
  `weak_map` breaks saves.
- **Leave / session cleanup must not touch the persistence map.** Do not rebuild
  `PlayerStatsMap` without a player on leave. Session maps (`AllPlayers`,
  per-session scores) may drop keys — the persistence `weak_map` must not. See
  `sys_player_data`.
- **Values are immutable.** Replace the whole table via rebuild + `set` (below);
  never mutate a persistable field in place.
- **Schema is careful.** Do not remove persistable fields. Add fields only via
  `sys_persistence_migration` + updating every carry-all helper.

### The three pieces

**1. A module-level `weak_map`** (the store):

```verse
var PlayerStatsMap <public> : weak_map(player, game_player_table) = map{}
```

- `weak_map(player, v)` — persists `v` per player. The engine may GC unreferenced
  entries; **you must never delete keys yourself**.
- Declared at module scope (not inside a device) so every system shares it.

**2. A `<persistable>` data class** (what gets saved):

```verse
game_player_table <public> := class<final><persistable>:
    Version<public> : int = 0
    PlayerLevel  <public> : player_level      = player_level{}
    PlayerWallet <public> : player_wallet     = player_wallet{}
    PlayerTimeData <public> : player_time_data = player_time_data{}
    Stats        <public> : player_stats       = player_stats{}
```

Rules for a persistable class:

- **Must** be `<final>` and `<persistable>`.
- Every field must itself be persistable (scalars, strings, arrays/maps of
  persistable, or other `<final><persistable>` classes) and **have a default**.
- Keep a `Version : int` field so you can migrate old saves when the shape
  changes.
- Nest persistables — `game_player_table` holds `player_wallet`, `player_level`,
  etc., each its own `class<final><persistable>`.

**3. A manager** that initializes and updates entries:

```verse
save_service <public> := class():
    InitializePlayer(Agent : ?agent) : void =
        if:
            RealAgent := Agent?
            Player := player[RealAgent]
            Player.IsActive[]
        then:
            if (ExistingStats := PlayerStatsMap[Player]):
                # rejoin — keep persisted stats
            else:
                if (set PlayerStatsMap[Player] = game_player_table{}):
                    # new player — fresh table
```

### Reading & writing

Read is a **failable** map lookup; write is a **failable** `set`:

```verse
if (OldTable := PlayerStatsMap[Player]):        # read
    Value := OldTable.PlayerWallet.Currencies

if (set PlayerStatsMap[Player] = NewTable):     # write (guard it in `if`)
    Print("saved")
```

### Immutable update-and-store pattern

Persistable classes are treated as **immutable values**: you don't mutate a field
in place, you build a new table and store it. A wallet manager is the model:

```verse
# helper: copy the table, swapping one nested persistable
UpdateWallet(OldTable : game_player_table, NewWallet : player_wallet)<transacts> : game_player_table =
    game_player_table:
        Version   := OldTable.Version
        PlayerLevel := OldTable.PlayerLevel
        PlayerWallet := NewWallet          # the changed part
        # …carry the rest

AddPlayerCurrency(Agent : ?agent, CurrencyName : string, Amount : int) : void =
    if:
        RealAgent := Agent?
        Player := player[RealAgent]
        OldTable := PlayerStatsMap[Player]
    then:
        NewWallet := MakePlayerWallet(OldTable.PlayerWallet, UpdatedCurrencies)
        if (set PlayerStatsMap[Player] = UpdateWallet(OldTable, NewWallet)):
            # persisted
```

Flow: **look up player → look up old table → compute new nested value → build a
new table → `set` it back into the `weak_map`.** Guard every failable step in the
`if:` head.

### Carry-all: one shared copy helper (critical)

Every write rebuilds the **whole** table. If each manager has its own partial
helper that only lists the fields it knew about when it was written, **adding a
new nested field later silently resets that field to its default on every other
system's write** (wallet save wipes new stats, XP save wipes time data, etc.).

**Prefer one shared helper** that always copies every field and only swaps the
arguments you pass as "changed". Simplest form that stays valid Verse: one
function per nested field, but **every** function lists **every** field:

```verse
# Every helper must copy ALL nested fields — not just the one it changes
UpdateWallet(OldTable : game_player_table, NewWallet : player_wallet)<transacts> : game_player_table =
    game_player_table:
        Version := OldTable.Version
        PlayerLevel := OldTable.PlayerLevel
        PlayerWallet := NewWallet
        PlayerTimeData := OldTable.PlayerTimeData
        Stats := OldTable.Stats                 # don't forget fields other systems own

UpdateLevel(OldTable : game_player_table, NewLevel : player_level)<transacts> : game_player_table =
    game_player_table:
        Version := OldTable.Version
        PlayerLevel := NewLevel
        PlayerWallet := OldTable.PlayerWallet
        PlayerTimeData := OldTable.PlayerTimeData
        Stats := OldTable.Stats
```

When you add a nested persistable to the table, update **every** helper in the
same change. Missing one helper = silent data loss on the next save from that
system. See `sys_persistence_migration` for the add-field checklist.

### Gotchas

- **Removing a player from `PlayerStatsMap` on leave** — breaks persistence. Leave
  the key alone; session maps are the ones that drop entries.
- Forgetting `<final>` or defaulting a field → the class won't be `<persistable>`.
- Mutating a field and expecting it to save — build a new value and `set` it into
  the map instead.
- Not guarding the `set PlayerStatsMap[Player] = …` in an `if` — it's failable.
- No `Version` field — you'll have no clean way to migrate when the schema grows.
- **Partial copy helpers that omit a field** — every write from another system
  resets the omitted field to default. Centralize, or update all helpers when the
  table grows (see `sys_persistence_migration`).
