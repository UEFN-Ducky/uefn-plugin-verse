---
description: "Why scoped Island Settings mutator keys are readonly via MCP — CreativeMutator_* and FortPlayerSettingsComponentBase — and what to do instead"
metadata:
  order: 3
  label: "Scoped / readonly keys"
  default_enabled: false
  load_condition: "Island Settings key is readonly_override, CreativeMutator_*, FortPlayerSettingsComponentBase, or set_creative_device_fields failed on a scoped property"
---

# Scoped Island Settings keys (readonly via MCP today)

`ToyOptionsComponent` stores many overrides as **scoped** names:

```
PropertyScope="CreativeMutator_WeaponSettings", PropertyName="Enabled"
→ inspect key: CreativeMutator_WeaponSettings:Enabled
```

`inspect_creative_device` surfaces these as:

```json
{
  "type": "readonly_override",
  "value": "False",
  "error": "Failed to find property 'CreativeMutator_WeaponSettings:Enabled' …"
}
```

They are **readable as override strings** but **not writable** through `actor.set_editor_property` (what `set_creative_device_fields` uses).

## Families that usually hit this

| Scope prefix | Examples |
|--------------|----------|
| `CreativeMutator_*` | AllowBuilding, AutoPickup*, WeaponSettings, EnvironmentDamage, KillsFeedback, NewHUD |
| `FortPlayerSettingsComponentBase` | RespawnTime, bAllowItemDrop, GravityPreset, Nameplate*, siphon values |
| `FortPlayerZoneSettingsComponent` | TimeOfDayOverride, Fog*/Light* overrides, CameraFilter |

## What to do

1. Prefer an **unscoped** writable twin when it exists (`bGliderRedeployable`, `VoiceChat`, `MaxPlayers`, …).
2. For true scoped-only options → set them in the UEFN **Details** panel on Island Settings (or ask for a future MCP override writer).
3. Do **not** loop `set_creative_device_fields` / `execute_python` retries on `readonly_override` keys.

## Side components (also on the actor)

Voice, music, sidekicks, temporary teams live on **instance components**, not always as top-level ToyOptions keys:

- `BP_UserOptionComponent_VoiceChat_C`
- `BP_UserOptionComponent_Music_C`
- `BP_FortUserOptionsComponent_Sidekicks_C`
- `BP_UserOptionComponent_TemporaryTeams_C`

Treat those as out of scope for `set_creative_device_fields` unless inspect exposes a plain writable key.
