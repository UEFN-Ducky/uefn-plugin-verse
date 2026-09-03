---
description: "Evolving saved data safely — the Version field, why defaulted persistable fields are backward-compatible, and one-time migration on load"
metadata:
  order: 27
  label: "Game systems — persistence versioning & migration"
  default_enabled: false
  load_condition: "Changing the shape of already-saved player data — adding/removing persistable fields, or migrating old saves to a new schema"
---

## Persistence versioning & migration

Players carry old saves forever. Changing a `<persistable>` schema without a plan
either silently loses data or breaks loads. The `Version` field is your safety net
(names below are generic — see `persistence` for the base pattern).

### Why every persistable table carries a Version

```verse
game_player_table := class<final><persistable>:
    Version <public> : int = 0        # bump this when the schema changes
    Stats   <public> : player_stats = player_stats{}
    # …other nested persistables
```

Keep a single source of truth for the current number:

```verse
CurrentSaveVersion<public> : int = 3
```

### What's safe vs what needs migration

| Change | Safe automatically? | Why |
|--------|--------------------|-----|
| **Add** a new field (with a default) | ✅ yes* | old saves deserialize with the field's default value |
| **Add** a nested `<persistable>` (defaulted) | ✅ yes* | same — the nested default fills in |
| **Rename** a field | ❌ no | the old value is lost; migrate it into the new field |
| **Change a field's meaning/units** | ❌ no | e.g. seconds→ms; convert old values on load |
| **Remove** a field | ❌ avoid | leaves orphan data / breaks loads for existing players; leave the field unused or migrate into a new field instead |
| **Change a field's type** | ❌ no | not directly persistable-compatible; add a new field + migrate |

\* **Safe for load, not for write** — deserialization fills the new default, but
every existing partial-copy helper that rebuilds the table **without listing the
new field** will keep resetting it to default on the next wallet / XP / time
write. Adding a nested persistable is only fully safe after you update the copy
helpers (or switch to one shared carry-all helper — see `persistence`).

Because defaulted fields are backward-compatible on **load**, **most additive
changes need no Version migration** — just add the field with a default **and**
fix every table-rebuild helper. Reserve Version migration for renames, unit
changes, and derived values.

### One-time migration on load

Run migration exactly once, when you first touch a player's table (in the
persistence manager's `InitializePlayer`), then store the upgraded table so it never
runs again:

```verse
InitializePlayer(Agent : ?agent) : void =
    if:
        RealAgent := Agent?
        Player := player[RealAgent]
        Player.IsActive[]
    then:
        if (Existing := PlayerStatsMap[Player]):
            if (Existing.Version < CurrentSaveVersion):
                if (set PlayerStatsMap[Player] = MigrateTable(Existing)): {}   # upgrade in place
        else:
            if (set PlayerStatsMap[Player] = game_player_table{ Version := CurrentSaveVersion }): {}
```

### The migration function (step through versions)

Apply each version's fix in order so a very old save catches up through every step,
and stamp the new version last:

```verse
MigrateTable(Old : game_player_table)<transacts> : game_player_table =
    var Working : game_player_table = Old

    # v0 -> v1: points used to live in the wallet; move them into Stats
    if (Working.Version < 1):
        Migrated := player_stats{ Points := LegacyPointsFrom(Working), Kills := Working.Stats.Kills }
        set Working = UpdatePlayerStats(Working, Migrated)

    # v1 -> v2: playtime changed from seconds to milliseconds
    if (Working.Version < 2):
        set Working = ScalePlaytime(Working, 1000)

    # stamp current version so migration never re-runs
    return SetVersion(Working, CurrentSaveVersion)
```

Each step is the usual **immutable rebuild** (copy the table, swap one nested
value — see `persistence`). `SetVersion` just rebuilds the table with
`Version := CurrentSaveVersion`.

### Checklist when adding a nested persistable

1. Add the field (with a default) to the shared `<persistable>` table.
2. Update **every** `Update…(OldTable, NewX)` helper to copy the new field from
   `OldTable` — or better, replace them with one shared carry-all helper
   (`persistence`).
3. Add the manager + persistence manager that writes through that helper.
4. Only bump `CurrentSaveVersion` if you also need to transform old values (not
   for a plain additive field).

Skipping step 2 is the most common silent data-loss bug: the new field looks fine
after join, then vanishes the first time another system saves.

### Rules

- **Do not remove persistable fields** — leave unused or migrate into a new field;
  deleting schema breaks existing saves.
- **Bump `CurrentSaveVersion` whenever you change the schema in a non-additive
  way** — and add a matching `if (Version < N)` step.
- **Never reorder or reuse a field's meaning silently** — add a new field and
  migrate into it.
- **Migrate on first load, then store** — don't migrate on every read.
- **When adding a field, update every table-rebuild helper** (or use one shared
  carry-all) — otherwise other systems' writes wipe the new data.
- Test with a real old save (an account that played the previous build), not just a
  fresh join — fresh joins skip migration entirely.
- Keep migration `<transacts>` and pure (no world side effects); it only reshapes
  data.
