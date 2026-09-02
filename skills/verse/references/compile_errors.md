---
description: "Verse compiler error catalogue — every Script error code agents actually hit (3512 no_rollback, 3582 divergent initialiser, 3593 internal module, 3588 ambiguous identifier, 3104, 3506, 3509, 3524, 3511, 3514, 3100, 9002) with the real cause and a compiling fix"
metadata:
  order: 3
  label: "Compile errors — code → cause → fix"
  default_enabled: false
  load_condition: "workspace_compile_verse or the UEFN build reported a Script error NNNN, or workspace_list_verse_errors names a file — load this before editing"
---

## Compile errors — code → cause → fix

Read the code number, jump to it, apply the fix at the reported line. Counts are
from real agent sessions (113 errors), so the first four cover most of what you
will see. **The offline LSP (`workspace_list_verse_errors`) cannot see 3512, 3582,
3593, 3588 or 3532** — only `workspace_compile_verse` finds them.

### 3512 — "calls a function that has the 'no_rollback' effect, which is not allowed by its context" (39 hits)

Cause: a function with **no effect specifier** is `no_rollback`; you called it inside
a failure context (`if (…)` head, `if:` block, `for` filter, `[]` argument, or a
`<decides>` body).

```verse
# before
AliveCount() : int = …
if (AliveCount() = 0):                     # 3512

# fix — give the helper <transacts> (it only reads/writes fields)
AliveCount()<transacts> : int = …
if (AliveCount() = 0):

# or bind first
Alive := AliveCount()
if (Alive = 0):
```

Variants with the same code:

- "This archetype instantiation constructs a class that has the 'transacts' effect,
  which is not allowed by its context" — you built `foo{}` at **module scope**. Move
  it into `OnBegin` or a device field.
- "This division can fail, but `F` does not have the `<decides>` effect" — integer
  `/` outside a failure context. Use `if (Q := Floor[(A * 1.0) / (B * 1.0)])`.
- "calls a function (`WaitForFirstPlayer`) that has effects that are not allowed" —
  a `<suspends>` call from a sync function. Add `<suspends>` to the caller or
  `spawn{}` it.

### 3582 — "Divergent calls (calls that might not complete) cannot be used to define data-members" (17 hits)

Cause: a class field initialiser calls a function.

```verse
var Lanes : []int = ComputeLanes()      # 3582
var Lanes : []int = array{}             # fix; set Lanes = ComputeLanes() in OnBegin
```

Only literals, archetypes (`array{}`, `map{}`, `option{}`, `vector3{…}`, `my_class{}`)
and `<converges>` calls may initialise a field.

### 3593 — "Invalid access of internal module / scoped class from control scope" (16 hits)

Cause: importing a **nested** Assets-digest module (`using { Materials.HexPlatforms }`)
or constructing a `scoped{…}` class (`EP_Weapon_Pistol{}`) from another module.
Only top-level Assets modules are importable; scoped classes are usable only in
their own scope.

Fix: move the asset up to a top-level Content folder (or a folder the digest
exposes as `<public>`), rebuild, `search_verse_digest` the new path, then import
that. For your own modules, add `<public>` to the module declaration.

### 3588 / 3532 — "Ambiguous identifier; could be (…:)Distance, (/Verse.org/SpatialMath:)Distance" (9 hits)

Cause: you named a field, local or parameter the same as a module function
(`Distance`, `Dogs` twice in one module, …).

Fix: rename the binding (`Dist`, `DistToTarget`). Never use these names for your
own bindings: `Distance DistanceSquared Dot Cross Normalize Lerp Sqrt Sin Cos Tan
Floor Ceil Round Int Min Max Clamp Print Sleep Exp Log Pow`. Never reuse a
module-level name inside a function in the same module.

### 3104 — "Dangling `=` assignment with no expressions or empty braced block on its right hand side" (5 hits)

Cause: a function signature split across lines, so the `=` ends a line with nothing
after it.

```verse
# before
OnHit(Agent : agent,
      Damage : float) : void =
# fix — one line
OnHit(Agent : agent, Damage : float) : void =
```

Also raised by an empty body: put at least one expression (or `{}`) after `=`.

### 3506 — "Unknown identifier `X`" / "Unknown member `X` in `entity`" (6 hits)

Cause: an invented API (`GetPlayspaceForEntity` on `entity` without the Playspaces
import, `NamedColors.White` with only the submodule imported) or a missing
`using`. Epic doc samples frequently omit imports.

Fix: `search_verse_digest("X")`; if present, add the `using` path shown. If absent,
it is almost certainly invented — but core intrinsics such as `Abs`,
`ConcatenateMaps`, `Max`, `Min` are not listed in the digests and still compile, so
the compiler's own "Unknown identifier" is the final word, not the digest. Common: `collision_point` / `FindSweepHits`
need `/Verse.org/SceneGraph`; `GetPlayspace()` needs `/Fortnite.com/Playspaces`;
`fort_character` needs `/Fortnite.com/Characters`; `animation_sequence` needs
`/Verse.org/Assets`; `color{}` needs `/Verse.org/Colors`.

### 3509 — type mismatch / "No overload of the function matches" (5 hits)

- `tuple(player, rational)` where `tuple(agent, int)` expected → integer `/` gave a
  `rational`; convert: `if (N := Floor[(A * 1.0) / (B * 1.0)])`.
- "No overload of `ToString` matches (:logic)" → there is no `ToString` for `logic`;
  write `if (Flag?) then "true" else "false"`.
- "expects []int but this initializer is []tuple(…)" → you used the `array:` block
  form, which builds a tuple per line. Use `array{1, 2, 3}`.
- A handler typed `(Player : player)` subscribed to a `listenable(agent)` → match the
  payload exactly (`Arg : agent`, or `Arg : tuple(agent, float)` for
  `ReleasedEvent`).

### 3524 — "Must be an array, map, or generator after ':' inside for" (3 hits)

Cause: iterating something that is not iterable, usually because a missing `using`
left a generator call unresolved (`FindSweepHits` without SceneGraph). Fix the import
first; then iterate arrays, maps, or `generator(t)` values only.

### 3502 — "Only 4 persistent `var`s allowed (used 5)" (verified)

An island may declare at most **four** `weak_map(player, …)` persistent `var`s in
total, across every file. Player Core + Economy + Progression + Time Tracker already
use all four; a fifth (yours, or one from another pack) fails the build. Fix: nest
the new data as a field on an existing persistable table (`sys_owned_weapons` shows
the pattern), never add a fifth map.

### 3509 (variant) — "The assignment's left hand expression type … cannot be assigned to"

You wrote `set` on an immutable binding: `Prev := 0.0` then `set Prev = P`, or a
name bound in an `if (X := Map[K])` head. Declare it `var Prev : float = 0.0`, or
copy the bound value into a `var` before mutating.

### 3511 — "uses parentheses to call a function that has the 'decides' effect"

`<decides>` functions are called with `[]`: `if (Team := Collection.GetTeam[Agent])`.

### 3514 — "Cannot use reserved identifier `_` as definition name"

`_` is reserved. Name the loop variable (`for (Unused : Items)`) or use the value.

### 3100 — "vErr:S88: Expected expression"

Parse error: check 4-space indentation, a `#` comment (never `//` or `/* */`), an
unbalanced `{` `}` or `(` `)`, or a stray `:` at the end of a one-line `if`.

### 9002 — "Cannot find `AI-CatReacts` in Package /…/_Verse/Assets"

An Assets-digest module that is not in this project. The asset folder must exist
under `Content/` and the project must have been built once so the digest lists it.

### Tool-side errors that look like compile errors

| Message | Cause | Fix |
|---------|-------|-----|
| "STALE REFLECTION — field has no compiled hash" | You wired an `@editable` before building | `workspace_compile_verse` → `reload_listener` → retry once |
| "Verse behavior not found … Build Verse Code first" | `set_npc_definition_behavior` before the class existed | build, then retry |
| "Verse struct … not found under _Verse. Recompile Verse" | array field of a new struct, not built | build, then retry |
| "wire_verse_device_array … one target per call" | older app; pass one target per call, or upgrade | – |

### After fixing

`workspace_list_verse_errors` (offline, catches syntax) → `workspace_compile_verse`
(real build, catches effects/modules) → only then `wire_verse_device_*`,
`set_verse_editable`, `set_npc_definition_behavior`.
