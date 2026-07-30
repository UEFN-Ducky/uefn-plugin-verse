---
description: "Data — scalars, arrays/maps/tuples/options, bindings & mutation, arithmetic, string/number formatting, and collection operations (Length, iteration, +=)"
metadata:
  order: 8
  label: "Types, containers & operations"
  default_enabled: false
  load_condition: "Working with numbers/strings/arrays/maps/tuples, mutating state (var/set), or doing math/formatting"
---

## Types, containers & operations

Type names are **lowercase**. Language types are stable; engine/gameplay types
(`vector3`, `agent`, `trigger_device`) come from the digests.

### Scalars

| Type | Notes |
|------|-------|
| `int` | whole numbers |
| `float` | decimals — literals need a dot: `1.0`, `3600.0` |
| `logic` | boolean: `true` / `false`. Test with `X?` in a failure context |
| `string` | text, `"…"`, interpolate with `"{Expr}"` |
| `char` | single character |
| `void` | no value (common return type) |
| `any` | top type (rare) |

`int` and `float` don't auto-convert — write `float` literals with `.0`, and go
`float → int` with `Floor[…]` / `Round[…]` / `Int[…]` (failable, use `[]`):

```verse
if (Value := Floor[Hours]):
    set TempHours = Value
```

### Bindings & mutation

```verse
X := expr                 # immutable, type inferred
X : t = expr              # immutable, typed
var X : t = expr          # mutable
set X = expr              # reassign a var
set Count += 1            # compound: += -= *= /= also work
```

- `:=` defines; `=` inside a failure context **compares**. Don't confuse them.
- Fields follow the same rule: `var Count : int = 0` vs `MaxCount : int = 10`.

### Containers

| Form | Type | Literal | Access |
|------|------|---------|--------|
| Array | `[]t` | `array{}`, `array{A, B}` | `Arr[Index]` — **failable** |
| Map | `[k]v` | `map{}` | `Map[Key]` — **failable** |
| Tuple | `tuple(a, b)` | `(A, B)` | `T(0)` or `T[0]` |
| Option | `?t` | `false`, `option{X}` | `X?` — **failable** |

```verse
var UpdatedCurrencies : []currency_data = array{}
var PlayerStatsMap : weak_map(player, game_player_table) = map{}
@editable PropDisguises : []disguise_device = array{}
```

- All indexed access **fails** on a bad key/index → use inside `if`/`for` (see the
  `effects` reference).
- `weak_map(player, v)` is the persistence map keyed by player — see the
  `persistence` reference.

### Array operations

```verse
Arr.Length                                  # element count (int)
set UpdatedCurrencies += array{NewEntry}    # append (build a new array)
for (Item : Arr): …                         # iterate elements
for (I := 0..Arr.Length - 1): …             # iterate indices
if (First := Arr[0]): …                     # safe first element
GetRandomInt(0, Arr.Length - 1)             # random index (with /Verse.org/Random)
```

Build arrays functionally — accumulate into a `var []t` with `+=` inside a `for`,
then store the result. Maps update with a failable `set`:
`if (set PlayerStatsMap[Player] = NewTable):`.

### Tuples

Multiple values without a named type; index positionally:

```verse
YPR := CurrentRotation.GetYawPitchRollDegrees()
if (Yaw := YPR[0], Pitch := YPR[1]):        # destructure via failable index
    set LastYaw = Yaw
```

### Arithmetic & comparison

- `+ - * /` on numbers; `/` on `int` is integer division — cast to `float` first
  for fractions (`TotalTime / 3600.0`).
- Compare: `< <= > >=`, and `=` / `<>` (equal / not-equal) **in a failure
  context**: `if (Found = false):`, `for (…, Key <> OutAgent):`.
- Combine: `and`, `or`, `not` — `if (Dist <= Range and Dist < ClosestDistance):`.
- Handy math (from `/UnrealEngine.com/…` and `/Verse.org/…`): `Abs`, `Max`, `Min`,
  `Floor`, `Distance(A, B)`, `GetRandomInt`. Confirm signatures in the digest.

```verse
TempH := Max(0.0, Health - Damage)
Dist := Distance(TowerPos, PropPos)
```

### Strings & number formatting

Interpolation embeds any expression; build display strings by hand (e.g. a
time formatter, or currency scaling):

```verse
"{MinutesString}:{SecondsString}"
var HoursString : string = if (TempHours < 10) { "0{TempHours}" } else { "{TempHours}" }
```

`SomeString.Length` gives character count. For on-screen text use a `<localizes>`
`message` helper, not a raw `string` (see the `devices` reference).

### Math/spatial types (from the digests)

`vector3{X:=, Y:=, Z:=}`, `rotation`, `transform`, `vector2` for UI sizes. Read
world position via `Prop.GetTransform().Translation`; move with
`PropObject.MoveTo(TargetPos, Rotation, Time)` / `MoveTo(...)` inside a
`<suspends>` loop. Exact members live in `UnrealEngine.digest.verse` — search
before using.
