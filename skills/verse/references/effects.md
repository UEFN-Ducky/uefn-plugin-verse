---
description: "Effect specifiers (<transacts> <decides> <computes> <converges> <reads> <suspends> …), what a function with NO specifier really is (no_rollback), which effects may call which, the failure model, <decides> chaining, and option handling"
metadata:
  order: 6
  label: "Effects, failure & options"
  default_enabled: false
  load_condition: "Choosing effect specifiers for a function, a compile error mentioning no_rollback / transacts / decides / divergent, calling a failable [] function, or handling options (?t, X?, option{})"
---

## Effects, failure & options

An effect in `<>` after the parameter list declares **what the function is allowed
to do**. The compiler enforces the set at every call site, so the effect you pick
decides *where the function may be called from*. Wrong effects were the single
largest source of real compile errors in agent sessions (E3512, 39 of 113).

### The effect table

| Effect | Means | Callable inside a failure context? | Typical use |
|--------|-------|-----------------------------------|-------------|
| *(none)* | **Default effects**: may read, write, allocate — and is **`no_rollback`**. The runtime cannot undo it. | **No** | Event handlers, `OnBegin` helpers that only run in straight-line code |
| `<transacts>` | May read/write/allocate **inside a transaction**: rolled back if the enclosing failure context fails. | Yes | Getters, setters, mutators, anything you will ever call in an `if` |
| `<decides>` | **Can fail**. Called with `[]`. Body is itself a failure context. Always pair it with the effect that says what the body does: `<decides><transacts>` (touches state) or `<decides><reads>` / `<decides><computes>` (pure query). The digest has 230 `<transacts><decides>` and zero bare `<decides>`. | Yes (that is the only place it can be called) | Lookups, validations, "attack succeeds or not" |
| `<reads>` | Reads mutable/world state (time, RNG seed, floating point env), never writes. Used by `Floor`, `Sqrt`, `Sin`, `Distance`, `Lerp`, `GetSecondsSinceEpoch`. | Yes | Pure-ish math you do not want to mark `<transacts>` |
| `<computes>` | **Pure**: same output for the same input, forever; no heap, no world. May only call other `<computes>` / `<converges>`. | Yes | Arithmetic helpers, string builders |
| `<converges>` | `<computes>` plus **guaranteed to terminate**. The only effect allowed in a class field initialiser. | Yes | Constructors, constant builders (`operator'+'` on `color` is `<converges>`) |
| `<suspends>` | **Async**: may `Sleep`, `Await`, run across frames. May call anything. | **No** | `OnBegin`, game loops, anything time-based (see `async`) |
| `<varies>` | Documented by Epic (same input may give different output, no mutation). Not used by any digest declaration; you will not need it. | – | – |

Access specifiers share the `<>` slot and come first: `<public> <private>
<internal> <protected>`, plus `<override> <final> <native> <constructor>`.

```verse
GetCurrency<public>(Name : string)<transacts> : float = …
TryBuy<public>(Agent : agent, Cost : float)<decides><transacts> : void = …
RunPrizeSelection<private>(Agent : agent)<suspends> : void = …
```

### Who may call whom

| Caller | May call | May **not** call |
|--------|----------|------------------|
| *(none / default)* | anything sync, including other default functions; `<decides>` only inside an `if`/`[]` | `<suspends>` |
| `<transacts>` | `<transacts>`, `<reads>`, `<computes>`, `<converges>`; `<decides>` inside an `if`/`[]` | **default (no_rollback) functions**, `<suspends>` |
| `<decides><transacts>` | same as `<transacts>`, plus any failable expression directly in its body | default functions, `<suspends>` |
| `<computes>` | `<computes>`, `<converges>` | `<reads>` (so no `Floor`, `Sqrt`, `Distance`), `<transacts>`, default |
| `<converges>` | `<converges>` | everything else |
| `<suspends>` | anything | – |

**The trap (E3512):** a helper with no specifier is `no_rollback`. Calling it
inside `if (…)`, an `if:` block, a `for` filter, a `[]` argument, or a `<decides>`
body is an error, because the failure context must be able to roll back.

```verse
# WRONG — GetCurrency has no effect, so it is no_rollback
GetCurrency(Name : string) : float = …
if (GetCurrency("Coins") >= Cost):                          # E3512

# RIGHT (a) — make the helper transactional
GetCurrency(Name : string)<transacts> : float = …
if (GetCurrency("Coins") >= Cost):

# RIGHT (b) — bind first, test the local
Coins := GetCurrency("Coins")
if (Coins >= Cost):
```

Rule of thumb: **every getter, setter and small helper gets `<transacts>`** unless
it needs `<suspends>`. Reserve "no specifier" for handlers whose body would not
compile as `<transacts>` (they call default functions or do `spawn`).

### Field initialisers must converge (E3582)

```verse
using { /Fortnite.com/Devices }
using { /Verse.org/SpatialMath }
my_device := class(creative_device):
    var Rows : []int = BuildRows()           # E3582 — divergent call
    var Rows : []int = array{}               # OK; fill in OnBegin
    Origin : vector3 = vector3{Forward := 0.0, Left := 0.0, Up := 0.0}   # archetype OK
    # /Verse.org/SpatialMath vector3 is Forward/Left/Up. The X/Y/Z vector3 lives in
    # /UnrealEngine.com/Temporary/SpatialMath — never mix the field names with the import.
```

Only literals, archetypes (`array{}`, `map{}`, `option{}`, `vector3{…}`, `foo{}`)
and `<converges>` calls are allowed on the right of a field's `=`.

### Module-scope instances (E3512 "archetype … has the 'transacts' effect")

A class whose constructor is `<transacts>` (any class with `var` fields) cannot be
instantiated at module scope. Create it in `OnBegin` or as a device field.

### The failure model — `<decides>` and `[]`

Verse has no exceptions. Some expressions **fail** (produce nothing) and that
failure *chooses a branch*. A `<decides>` function is one that can fail; you invoke
it with **square brackets** `[]`, and only inside a failure context:

```verse
Player.IsActive[]                 # <decides> — succeeds or fails the branch
if (Value := Floor[Hours]):       # <decides><reads>: float → int
    set TempHours = Value
AllPlayers[Agent]                 # map lookup — fails if key absent
Buttons[Index]                    # array index — fails if out of range
```

**Failure contexts** (the only places a failable expression may appear):

- the head of `if (…)` and every line under an `if:` block
- the head and filter clauses of `for (…)`
- the arguments of a `[]` call or index
- operands of `not`, `and`, `or`
- the body of a `<decides>` function

**Not** a failure context: the body of a plain `<transacts>` function, a `then:`
block, an `else:` block, a `<suspends>` body. Writing a failable lookup there is
the most common beginner error; wrap it in `if`.

Calling a `<decides>` function with `()` is E3511; a non-failable function with `[]`
is also an error.

### `<decides>` chaining — Epic's recommended shape

A `<decides>` body reads as a list of conditions. Each failable line is a check;
the first failure aborts and **rolls back** everything above it, so the mutations
at the bottom never half-apply:

```verse
MeleeAttack(Attacker : player, Target : player)<decides><transacts> : float =
    Target.IsAlive[]                            # fails: target not alive
    Weapon := Attacker.EquippedWeapon?          # fails: no weapon equipped
    InRange[Attacker, Target, Weapon.Reach]     # fails: out of reach
    Attacker.Stamina >= Weapon.Cost             # fails: too tired
    set Attacker.Stamina -= Weapon.Cost
    set Target.Health -= Weapon.Damage
    Weapon.Damage

# call site
if (Dealt := MeleeAttack[Attacker, Target]):
    Print("hit for {Dealt}")
```

(Epic's slide writes `<decides>` alone; add `<transacts>` because the body writes
state — bare `<decides>` on a mutating body is E3512.)

### Integer division is failable and produces `rational`

`A / B` on two `int`s can fail (divide by zero) and its type is `rational`, not
`int`. Outside a failure context it is E3512; passed where an `int` is expected it
is E3509.

```verse
if (Mins := Floor[(Total * 1.0) / 60.0]):     # int → float via * 1.0, then Floor[]
    Label := "{Mins}"
```

### Options — `?t`

```verse
var CurrentTarget : ?spawned_enemy_prop = false   # empty
set CurrentTarget = option{Prop}                   # wrap
if (Target := CurrentTarget?):                     # unwrap; branch only if present
    Fire(Target)
```

- `?t` option type, `false` the empty option, `option{X}` builds one, `X?` unwraps
  (fails in a failure context if empty).
- `@editable MaybeManager <public> : ?player_manager = false` — an optional editor
  ref the designer may leave unset.

### Returning success/failure from your own function

Prefer `<decides><transacts>` and let the body fail; call it with `[]`. Returning
`logic` is the alternative when callers need a value in straight-line code:

```verse
MapContains(Map : [int]logic, Key : int)<transacts> : logic =
    if (Map[Key]?) then true else false
```

### Choosing effects — quick guide

- Waits on time or events → `<suspends>`.
- Reads or mutates fields, may be used in an `if` → `<transacts>` (the default choice).
- A query that might have no answer → `<decides><transacts>`, call with `[]`.
- Pure arithmetic/string helper → `<computes>` (no `Floor`/`Sqrt`/`Distance` inside; those need `<reads>`).
- Produces on-screen text → `<localizes>` returning `message`.
- Field initialiser → literal or archetype only.

Full error-code catalogue with fixes: `compile_errors`.
